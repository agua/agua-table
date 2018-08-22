package Table::Stage;
use Moose::Role;
use Method::Signatures::Simple;

=head2

	PACKAGE		Table::Stage
	
	PURPOSE
	
		stage TABLE METHODS
		
=cut

=head2

	SUBROUTINE		updateStage
	
	PURPOSE

		ADD A STAGE TO THE stage TABLE

	INPUTS
	
		1. STAGE IDENTIFICATION - PROJECT, WORKFLOW, STAGE AND STAGE NUMBER
		
		2. INFORMATION FOR RUNNING THE STAGE (name, location, etc.)
		
	OUTPUTS
	
		1. A NEW ENTRY IN THE stage TABLE
		
	NOTES
	
		THE PARAMETERS FOR THIS STAGE ARE ADDED TO THE stageparameter TABLE

		IN A SEPARATE CALL TO THE $self->addStageParametersForStage() SUBROUTINE

=cut

method updateStage {
	my $json 		=	$self->json();
 	$self->logNote("$$ ");

	#### DO ADD STAGE WITH NEW NUMBER
	my $old_number = $json->{appnumber};
	$json->{appnumber} = $json->{newnumber};

	#### DO REMOVE STAGE WITH OLD NUMBER
	my $success = $self->_deleteStage($json);
	$self->logStatus("Successfully removed stage $json->{name} from stage table") if $success;
	$self->logError("Could not remove stage $json->{name} from stage table") if not $success;
	
	$success = $self->_addStage($json);
	$self->logStatus("Successfully added stage $json->{name} into stage table") if $success;
	$self->logStatus("Could not add stage $json->{name} into stage table") if not $success;

	#### UPDATE THE APPNUMBER FIELD FOR ALL STAGE PARAMETERS
	#### BELONGING TO THIS PROJECT, WORKFLOW, APPNAME AND APPNUMBER
	#### NB: USE OLD NUMBER
	$json->{appnumber} = $old_number;
	$json->{appname} = $json->{name};
	my $unique_keys = ["username", "projectname", "workflowname", "appname", "appnumber"];
	my $where = $self->db()->where($json, $unique_keys);
	my $query = qq{UPDATE stageparameter
SET appnumber='$json->{newnumber}'
$where};
	$self->logNote("$$ query", $query);
	$success = $self->db()->do($query);
	$self->logNote("$$ success", $success);
	
	$self->logStatus("Successful update of appnumber to $json->{newnumber} in stageparameter table") if $success;
	$self->logStatus("Could not update appnumber to $json->{newnumber} in stageparameter table") if not $success;
}

method getStages {
=head2

    SUBROUTINE:     getStages
    
    PURPOSE:

        GET ARRAY OF HASHES:
		
			[
				appname1: [ s ], appname2 : [...], ...  ] 

=cut

	#### SET OWNER 
	my $username = $self->username();
	#$self->logNote("$$ owner", $owner);

	my $query = qq{SELECT * FROM stage
WHERE username='$username'\n};
	$self->logDebug("query", $query);
	my $stages = $self->db()->queryhasharray($query);
	$stages = [] if not defined $stages;
	$self->logDebug("no. stages", scalar(@$stages));
	#$self->logNote("stages", $stages);

	return $stages;
}

method getStagesByWorkflow ( $data ) {
	$self->logNote("$$ data", $data);

	my $required = [ "username", "projectname", "workflowname" ];
	my $where = $self->db()->where($data, $required);
	my $query = qq{SELECT * FROM stage
$where};
	$query .= qq{ORDER BY projectname, workflowname, appnumber};
	$self->logNote("$$ $query");

	my $stages = $self->db()->queryhasharray($query);
	$stages = [] if not defined $stages;
	#$self->logDebug("$$ stages", $stages);
	$self->logDebug("# stages", scalar(@$stages));
	
	return $stages;
}

method addStage {
=head2

	SUBROUTINE		addStage
	
	PURPOSE

		ADD A STAGE TO THE stage TABLE

	INPUTS
	
		1. STAGE IDENTIFICATION - PROJECT, WORKFLOW, STAGE AND STAGE NUMBER
		
		2. INFORMATION FOR RUNNING THE STAGE (name, location, etc.)
		
	OUTPUTS
	
		1. A NEW ENTRY IN THE stage TABLE
		
	NOTES
	
		NB: THE PARAMETERS FOR THIS STAGE ARE ADDED TO THE stageparameter TABLE

		IN A SEPARATE CALL TO THE $self->addStageParametersForStage() SUBROUTINE

=cut

 	$self->logNote("$$ Common::addStage()");

	#### VALIDATE    
  $self->logError("User session not validated") and exit unless $self->validate();

  my $json 			=	$self->json();
	my $success = $self->_deleteStage($json);
	$success = $self->_addStage($json);
	$self->logStatus("Added stage $json->{name} to workflow $json->{workflow}") if $success;
}

method updateStageSubmit {
 	$self->logNote("PID $$");

  my $json 			=	$self->json();
	my $submit		=	$json->{submit};
	my $username	=	$json->{username};
	my $projectname		=	$json->{projectname};
	my $workflowname	=	$json->{workflowname};
	my $workflownumber	=	$json->{workflownumber};
	my $name		=	$json->{appname};
	my $number		=	$json->{appnumber};
	my $query = qq{UPDATE stage
SET submit='$submit'
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
AND workflownumber='$workflownumber'
AND number='$number'};
	$self->logNote("$$ $query");
	my $success = $self->db()->do($query);
	$self->logError("Failed to update workflow $json->{workflowname} stage $json->{number} submit: $submit'") if not defined $success or not $success;
	$self->logStatus("Updated workflow $json->{workflowname} stage $json->{number} submit: $submit") if $success;
}

method insertStage ( $data ) {
=head2

	SUBROUTINE		insertStage
	
	PURPOSE

		INSERT A STAGE AT A CHOSEN POSITION IN LIST OF STAGES

	INPUTS
	
		1. STAGE OBJECT CONTAINING FIELDS: project, workflow, name, number
		
		2. INFORMATION FOR RUNNING THE STAGE (name, location, etc.)
		
	OUTPUTS
	
		1. A NEW ENTRY IN THE stage TABLE
		
	NOTES
	
		NB: THE PARAMETERS FOR THIS STAGE ARE ADDED TO THE stageparameter TABLE

		IN A SEPARATE CALL TO THE $self->addStageParametersForStage() SUBROUTINE

=cut
 	$self->logDebug("data", $data);

	#### INSERT STAGE
	my $success = $self->_insertStage($data);
	$self->logDebug("success", $success);

	$self->notifyStatus($data) if $success;
	$self->notifyError($data, "Could not insert stage $data->{name} into workflow $data->{workflow}") if not $success;
}

method _insertStage ( $data ) {
#### GET THE STAGES BELONGING TO THIS WORKFLOW
	my $where_fields = ["username", "projectname", "workflowname"];
	my $where = $self->db()->where($data, $where_fields);
	my $query = qq{SELECT * FROM stage
$where};
	$self->logDebug("$$ query", $query);
	my $stages = $self->db()->queryhasharray($query) || [];
	$self->logDebug("$$ stages", $stages);
	
	#### GET THE STAGE NUMBER 
	my $number = $data->{appnumber};
	$self->logDebug("$$ number", $number);

	#### CHECK IF REQUIRED FIELDS ARE DEFINED
	my $required_fields = ["username", "owner", "projectname", "workflowname", "appname", "appnumber"];
	my $not_defined = $self->db()->notDefined($data, $required_fields);
    $self->logDebug("undefined values: @$not_defined") if @$not_defined;
	$self->notifyError($data, "undefined values: @$not_defined") and return if @$not_defined;

	#### JUST ADD THE STAGE AND ITS PARAMETERS TO stage AND stageparameters
	#### IF THERE ARE NO EXISTING STAGES FOR THIS WORKFLOW
	if ( not defined $stages or scalar(@$stages) == 0 ) {
		$self->_deleteStage($data);
		my $success = $self->_addStage($data);
		$self->notifyError($data, "Could not insert stage $data->{appname} into workflow $data->{workflow}") and return if not $success;
		
		$success = $self->addStageParametersForStage($data);
		$self->notifyError($data, "Could not insert stage $data->{appname} into workflow $data->{workflow}") and return if not $success;
		$self->notifyStatus($data);
		return;
	}

	#### INCREMENT THE number FOR DOWNSTREAM STAGES IN THE stage TABLE
	for ( my $i = @$stages - 1; $i > $number - 2; $i-- ) {
		my $stage = $$stages[$i];
		my $new_number = $i + 2;
		my $where_fields = ["username", "projectname", "workflowname", "appnumber"];
		my $where = $self->db()->where($stage, $where_fields);
		my $query = qq{UPDATE stage SET
appnumber='$new_number'
$where};
		$self->logDebug("$$ query", $query);
		my $success = $self->db()->do($query);
		$self->logDebug("$$ success", $success);
	}
	
	#### INCREMENT THE appnumber FOR DOWNSTREAM STAGES IN THE stageparameter TABLE
	for ( my $i = @$stages - 1; $i > $number - 2; $i-- ) {
		my $stage = $$stages[$i];
		my $new_number = $i + 2;
		my $where_fields = ["username", "projectname", "workflowname", "appnumber"];
		my $where = $self->db()->where($stage, $where_fields);
		my $query = qq{UPDATE stageparameter SET
appnumber='$new_number'
$where};
		$self->logDebug("$$ query", $query);
		my $success = $self->db()->do($query);
		$self->logDebug("$$ success", $success);
	}

	my $success = $self->_addStage($data);
	$self->logError("Could not _addStage $data->{appname} into workflow $data->{workflow}") and return 0 if not $success;

	#### REMOVE THEN ADD STAGE PARAMETERS
	$success = $self->addStageParametersForStage($data);

	return $success;
}


=head2

    SUBROUTINE     addStageParametersForStage
    
    PURPOSE

		COPY parameter TABLE ENTRIES FOR THIS APPLICATION

		TO stageparameter TABLE
		
=cut

method addStageParametersForStage ( $data ) {
	$self->logNote("$$ data", $data);
	
	#### GET APPLICATION OWNER
	my $owner = $data->{owner};
	
	#### GET PRIMARY KEYS FOR parameters TABLE
  my $username = $data->{username};
	my $package = $data->{package};
	my $appname = $data->{appname};
	my $projectname = $data->{projectname};
	my $workflowname = $data->{workflowname};
	my $number = $data->{appnumber};
	
	#### CHECK INPUTS
	$self->logError("appname $appname not defined or empty") and return if not defined $appname or $appname =~ /^\s*$/;
	$self->logError("username $username not defined or empty") and return if not defined $username or $username =~ /^\s*$/;
	$self->logNote("$$ username", $username);
	$self->logNote("$$ appname", $appname);

	#### DELETE EXISTING ENTRIES FOR THIS STAGE IN stageparameter TABLE
	my $success;
	my $query = qq{DELETE FROM stageparameter
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
AND appname='$appname'
AND appnumber='$number'};
	$self->logNote("$$ $query");
	$success = $self->db()->do($query);
	$self->logNote("$$ Delete success", $success);
	
	#### GET ORIGINAL PARAMETERS FROM parameter TABLE
	$query = qq{SELECT * FROM parameter
WHERE owner='$owner'
AND appname='$appname'};
    $self->logNote("$$ $query");
    my $parameters = $self->db()->queryhasharray($query);
	$self->logNote("$$ No. parameters", scalar(@$parameters));
	$self->logError("no entries in parameter table") and return if not defined $parameters;
	
	##### SET QUERY WITH PLACEHOLDERS
	my $table = "stageparameter";
	my $fields = $self->db()->fields($table);
	#my $fields_csv = $self->db()->fields_csv($table);

	$success = 1;
	my $args = {
		projectname => $projectname,
		workflowname => $workflowname,
		username	=>	$username
	};
	foreach my $parameter ( @$parameters )
	{
		$parameter->{username} = $username;
		$parameter->{projectname} = $projectname;
		$parameter->{workflowname} = $workflowname;
		$parameter->{appnumber} = $number;

		#### INSERT %OPTIONAL% VARIABLES
		$parameter->{value} =~ s/%project%/$projectname/g if defined $projectname;
		$parameter->{value} =~ s/%workflow%/$workflowname/g if defined $workflowname;
		$parameter->{value} =~ s/%username%/$username/g if defined $username;

		#### DO INSERT
		my $values_csv = $self->db()->fieldsToCsv($fields, $parameter);
		my $query = qq{INSERT INTO $table 
VALUES ($values_csv) };
		$self->logNote("$$ $query");
		my $do_result = $self->db()->do($query);
		$self->logNote("$$ do_result", $do_result);
		
		$success = 0 if not $do_result;
	}
	$self->logNote("$$ success", $success);
	
	return $success;
}




method _addStage ( $data ) {
=head2

	SUBROUTINE		_addStage
	
	PURPOSE

		INTERNAL USE ONLY: ATOMIC ADDITION OF A STAGE TO THE stage TABLE
        
=cut
 	$self->logDebug("data", $data);	
	
	$data->{submit}		=	0 if not defined $data->{submit} or $data->{submit} eq "";
	$data->{queued}		=	'00-00-00 00:00:00' if not defined $data->{queued};
	$data->{completed}	=	'00-00-00 00:00:00' if not defined $data->{completed};
	$data->{started}	=	'00-00-00 00:00:00' if not defined $data->{started};
	$data->{workflowpid}=	0 if not defined $data->{workflowpid};
	$data->{stagepid}	=	0 if not defined $data->{stagepid};
	$data->{stagejobid}	=	0 if not defined $data->{stagejobid};

	$data->{workflownumber}=	$data->{workflownumber} if not defined $data->{workflownumber};
	
	#### SET TABLE AND REQUIRED FIELDS	
	my $table = "stage";
	my $required_fields = ["username", "projectname", "workflowname", "workflownumber", "appname", "appnumber", "apptype"];
	
	my $inserted_fields = $self->db()->fields($table);

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($data, $required_fields);
    $self->logDebug("undefined values: @$not_defined") and return 0 if @$not_defined;
	
	#### DO ADD
 	$self->logNote("$$ Doing _addToTable(table, data, required_fields)");
	my $success = $self->_addToTable($table, $data, $required_fields, $inserted_fields);	
 	$self->logNote("$$ _addToTable(stagedata) success", $success);
	
#	#### ADD IT TO THE report TABLE IF ITS A REPORT
# 	$self->logNote("$$ data->{type}", $data->{type});
#	if ( $success and defined $data->{type} and $data->{type} eq "report" ) {
#		$data->{appname} = $data->{name};
#		$self->data($data);
#		
#		$success = $self->_addReport();
#	 	$self->logNote("$$ _addStage() success", $success);
#	}
	
	return $success;
}

method deleteStage ( $data ) {
=head2

	SUBROUTINE		deleteStage
	
	PURPOSE

		REMOVE STAGE FROM this.stages
        
        REMOVE ASSOCIATED STAGE PARAMETER ENTRIES FROM this.stageparameter
      
=cut
 	$self->logDebug("$$ data", $data);
	
	#### GET THE STAGES BELONGING TO THIS WORKFLOW
	my $where_fields = ["username", "projectname", "workflowname"];
	my $where = $self->db()->where($data, $where_fields);
	my $query = qq{SELECT * FROM stage
$where};
	$self->logNote("$$ query", $query);
	my $stages = $self->db()->queryhasharray($query);
	my $workflow = $data->{workflow} || "undef";
	if ( not defined $stages or scalar(@$stages) == 0 ) {
	 	$self->notifyError($data, "{ error: 'Table::Stage::deleteStage    No stages in workflow '$workflow'") and return;
	}
	
	#### REMOVE STAGE FROM stage TABLE
	my $success = $self->_deleteStage($data);
	my $appname = $data->{appname} || "undef";
 	$self->notifyError($data, "{ error: 'Table::Stage::deleteStage    Could not delete stage (appname: $appname) from stage table") and return if not defined $success;
	
	#### REMOVE STAGE FROM stageparameter TABLE
	my $table2 = "stageparameter";
	my $required_fields2 = ["username", "projectname", "workflowname", "appname", "appnumber"];
	$success = $self->_removeFromTable($table2, $data, $required_fields2);
 	$self->notifyError($data, "{ error: 'Table::Stage::deleteStage    Could not remove stage $data->{name} from $table2 table") and return if not defined $success;

	#### QUIT IF THIS WAS THE LAST STAGE IN THE WORKFLOW
	my $number = $data->{number};
	if ( $number > scalar(@$stages) ) {
	 	$self->notifyStatus($data, "Removed stage '$data->{appname}'' from workflow '$data->{workflowname}'");
		return;
	}

	#### OTHERWISE, DECREMENT THE number FOR DOWNSTREAM STAGES IN THE stage TABLE
	for ( my $i = $number; $i < @$stages; $i++ ) {
		my $stage = $$stages[$i];
		
		my $where_fields = ["username", "projectname", "workflowname", "appnumber"];
		my $where = $self->db()->where($stage, $where_fields);
		my $query = qq{UPDATE stage SET
appnumber='$i'
$where};
		$self->logNote("$$ query", $query);
		my $success = $self->db()->do($query);
		$self->logNote("$$ success", $success);

# 		#### UPDATE report TABLE IF ITS A REPORT
# 		if ( $stage->{type} eq "report" ) {
# 			$stage->{appname} = $stage->{name};
# 			$stage->{appnumber} = $stage->{number};
# 			my $where_fields = ["username", "project", "workflow", "appname", "appnumber"];
# 			my $where = $self->db()->where($stage, $where_fields);
			
# 			my $query = qq{UPDATE report SET
# appnumber='$i'
# $where};
# 			$self->logNote("$$ 'update report' query", $query);
# 			my $success = $self->db()->do($query);
# 			$self->logNote("$$ 'update report' success", $success);
			
# 		}
	}
	
	#### DECREMENT THE appnumber FOR DOWNSTREAM STAGES IN THE stageparameter TABLE
	for ( my $i = $number; $i < @$stages; $i++ ) {
		my $stage = $$stages[$i];
		my $where_fields = ["username", "projectname", "workflowname", "appnumber"];
		my $where = $self->db()->where($stage, $where_fields);
		my $query = qq{UPDATE stageparameter SET
appnumber='$i'
$where};
		$self->logNote("$$ query", $query);
		my $success = $self->db()->do($query);
		$self->logNote("$$ update stage number to $i, success", $success);
	}

 	$self->notifyStatus($data, "Removed stage $data->{name} from workflow $data->{workflow}");
}

method _deleteStage ( $data ) {
 	$self->logDebug("data", $data);
	
	#### CHECK UNIQUE FIELDS ARE DEFINED
	#### NB: ALSO CHECK name THOUGH NOT NECCESSARY FOR UNIQUE ID
	#### NNB: type IS NEEDED TO IDENTIFY IF ITS A REPORT
	my $required_fields = ["username", "projectname", "workflowname", "appnumber", "appname", "apptype"];
	my $not_defined = $self->db()->notDefined($data, $required_fields);
    $self->logError("undefined values: @$not_defined") and exit if @$not_defined;
	
	my $table = "stage";
	my $success = $self->_removeFromTable($table, $data, $required_fields);
	
	# #### REMOVE IT FROM THE report TABLE TOO IF ITS A REPORT
	# if ( $success and defined $data->{type} and $data->{type} eq "report" ) {
	# 	$self->data($data);		
	# 	$success = $self->_removeReport();
	# }
	
	return $success;
}



1;