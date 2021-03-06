package Table::Workflow;
use Moose::Role;
use Method::Signatures::Simple;

=head2

	PACKAGE		Table::Workflow
	
	PURPOSE
	
    workflow TABLE METHODS
	
=cut

method setWorkflowStatus ($username, $projectname, $workflowname, $status) {
	$self->logDebug("workflowname", $workflowname);

	my $data	=	{
		username			=>	$username,
		projectname		=>	$projectname,
		workflowname	=>	$workflowname
	};
	
	#### CHECK REQUIRED FIELDS
	my $table = "workflow";
	my $required_fields = ["username", "projectname", "workflowname"];
	my $not_defined = $self->db()->notDefined($data, $required_fields);
    $self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	#### UPDATE
	my $query	=	qq{UPDATE workflow
SET status='$status'
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'};
	$self->logDebug("query", $query);
	my $success = $self->db()->do($query);	
	$self->logDebug("success", $success);
	
	return $success;	
}


method isWorkflow ($username, $projectname, $workflowname) {
	#$self->logDebug("username", $username);

	my $query = qq{SELECT * FROM workflow
	WHERE username='$username'
	AND projectname='$projectname'
	AND workflowname='$workflowname'};
	my $workflow = $self->db()->queryhash($query);
	$self->logDebug("workflow", $workflow);
	if ( not $workflow or not defined $workflow->{workflowname} ) {
	       return 0;
	}

	return 1;
}

method getWorkflow ($username, $projectname, $workflowname) {
	#$self->logDebug("username", $username);
	
	my $query = qq{SELECT * FROM workflow
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'};
	#$self->logDebug($query);
	
	return $self->db()->queryhash($query);
}

method getWorkflowByNumber ( $username, $projectname, $workflownumber ) {	
	my $workflowname = $self->db()->query("SELECT workflowname FROM workflow
WHERE username='$username'
AND projectname='$projectname'
AND workflownumber=$workflownumber");

	return $workflowname;
}

method getWorkflowNumber ( $username, $projectname, $workflowname ) {	
	my $workflownumber = $self->db()->query("SELECT workflownumber FROM workflow
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'");

	return $workflownumber;
}

method getWorkflows {
	#### VALIDATE
	my $username = $self->username();
	return $self->_getWorkflows($username);
}

method _getWorkflows ($username) {
	#### GET ALL SOURCES
	my $query = qq{SELECT * FROM workflow
WHERE username='$username'
ORDER BY projectname, workflownumber, workflowname};
	$self->logDebug("$query");
	#$self->logDebug("self->db()", $self->db());

	my $workflows = $self->db()->queryhasharray($query);

	######## IF NO RESULTS:
	####	1. INSERT DEFAULT WORFKLOW INTO workflow TABLE
	####	2. CREATE DEFAULT WORKFLOW FOLDERS
	return $self->_defaultWorkflows() if not defined $workflows;

	return $workflows;
}

method getWorkflowsByProject ($projectdata) {
	$self->logDebug("projectdata", $projectdata);
	
	my $username = $projectdata->{username};
	my $projectname = $projectdata->{projectname};
	$self->logError("username not defined") and return undef if not defined $username;
	$self->logError("projectname not defined") and return undef if not defined $projectname;
	
	#### GET ALL SOURCES
	my $query = qq{SELECT * FROM workflow
WHERE username='$username'
AND projectname='$projectname'
ORDER BY workflownumber};
	$self->logDebug($query);
	my $workflows = $self->db()->queryhasharray($query);
	$workflows = [] if not defined $workflows;

	return $workflows;
}

method addWorkflow {
	my $data 		=	$self->json();
 	$self->logDebug("data", $data);

	my $success = $self->_addWorkflow($data);
 	return if not defined $success;
	$self->logError("Could not add workflow $data->{workflow} into project $data->{projectname} in workflow table") and exit if not defined $success;
	$self->logStatus("Added workflow $data->{name} to project $data->{projectname}");
}

method _addWorkflow ($data) {
#### ADD A WORKFLOW TO workflow, stage AND stageparameter	
	$self->logDebug("data", $data);
	
	#### SET TABLE AND REQUIRED FIELDS	
	my $table = "workflow";
	my $required_fields = [ "username", "projectname", "workflowname" ];
	my $fields = $self->db()->fields ( $table );

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($data, $required_fields);
	$self->logError("not defined: @$not_defined") and exit if @$not_defined;

	#### QUIT IF NAME EXISTS ALREADY
	my $query = qq{SELECT workflowname FROM workflow
WHERE username='$data->{username}'
AND projectname='$data->{projectname}'
AND workflowname='$data->{workflowname}'};
	my $already_exists = $self->db()->query($query);
	if ( $already_exists ) {
		$self->logError("Workflow name '$data->{workflowname}' already exists in workflow table");
		return 0;
	}
	
	#### REMOVE IF EXISTS ALREADY
	$self->_removeFromTable($table, $data, $required_fields);

	#### GET MAX WORKFLOW NUMBER IF NOT DEFINED
	my $username = $data->{username};
	$self->logDebug("username", $username);
	my $workflownumber = $data->{workflownumber};
	$self->logDebug("workflownumber", $workflownumber);
	if ( not defined $workflownumber ) {
		my $query = qq{SELECT MAX(workflownumber)
		FROM workflow
		WHERE username = '$username'
		AND projectname = '$data->{projectname}'};
		$self->logDebug("query", $query);
		my $workflownumber = $self->db()->query($query);
		$workflownumber = 1 if not defined $workflownumber;
		$workflownumber++ if defined $workflownumber;
		$data->{workflownumber} = $workflownumber;
	}

	#### DO ADD
	my $success = $self->_addToTable($table, $data, $required_fields, $fields );
	$self->logDebug("success", $success);

	#### ADD THE PROJECT DIRECTORY TO THE USER'S agua DIRECTORY
	my $fileroot = $self->util()->getFileroot($username);
	$self->logDebug("fileroot", $fileroot);
	my $directory = "$fileroot/$data->{projectname}/$data->{workflowname}";
	$self->logDebug("Creating directory", $directory);
	
	#### CREATE DIRECTORY IF NOT EXISTS	
	$success = mkdir( $directory, 0755 ) if not -d $directory;
	$self->logDebug("success", $success);

	return 1;
}

method removeWorkflow {
  my $data	=	$self->json();
 	$self->logDebug("data", $data);

	#### REMOVE WORKFLOW AND SUBSIDIARY DATA
	#### (STAGE, STAGE PARAMETERS, VIEW, ETC.)
	$self->_removeWorkflow($data);

	#### REMOVE WORKFLOW DIRECTORY
  my $username = $data->{'username'};
	$self->logDebug("username", $username);
	my $fileroot = $self->util()->getFileroot($username);
	$self->logDebug("fileroot", $fileroot);

	my $filepath = "$fileroot/$data->{projectname}/$data->{workflow}";
	$self->logDebug("Removing directory", $filepath);
	$self->logError("Could not find directory for workflow $data->{name} in project $data->{projectname}") and exit if not -d $filepath;
	
	$self->logError("Could not remove directory: $filepath") and exit if not File::Remove::rm(\1, $filepath);

	$self->logStatus("Removed workflow $data->{name} from project $data->{projectname}");
}

method _removeWorkflow ($data) {
	$self->logCaller("");
	$self->logDebug("data", $data);
	
	#### SET TABLE AND REQUIRED FIELDS	
	my $table = "workflow";
	my $required_fields = ["username", "projectname", "workflowname", "workflownumber"];

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($data, $required_fields);
	$self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	#### REMOVE FROM workflow
	my $success = $self->_removeFromTable($table, $data, $required_fields);
 	$self->logError("Could not remove $data->{workflow} from project $data->{projectname}") and exit if not defined $success;

	#### REMOVE FROM stage
	$table = "stage";
	my $stage_fields = ["username", "projectname", "workflowname"];
	$self->_removeFromTable($table, $data, $stage_fields);

	#### REMOVE FROM stageparameter
	$table = "stageparameter";
	my $stageparameter_fields = ["username", "projectname", "workflowname"];
	$self->_removeFromTable($table, $data, $stageparameter_fields);

	#### REMOVE FROM clusterworkflow
	if ( $self->db()->hasTable( "clusterworkflow") ) {
		$table = "clusterworkflow";
		my $clusters_fields = ["username", "projectname", "workflowname"];
		$self->_removeFromTable($table, $data, $clusters_fields);		
	}
	
	#### REMOVE FROM view
	if ( $self->db()->hasTable( "view") ) {
		$table = "view";
		my $view_fields = ["username", "projectname"];
		$self->_removeFromTable($table, $data, $view_fields);
	}

	return 1;
}

method renameWorkflow {
#### RENAME A WORKFLOW IN workflow, stage AND stageparameter
  $self->logDebug("");
	my $json 		=	$self->json();
	$self->logDebug("json", $json);

	#### GET NEW NAME
	my $newname = $json->{newname};
	$self->logError("No newname parameter. Exiting") and exit if not defined $newname;
	$self->logDebug("newname", $newname);

	#### VALIDATE
	$self->logError("User session not validated") and exit unless $self->validate();

	#### QUIT IF NEW NAME EXISTS ALREADY
	my $query = qq{SELECT workflowname FROM workflow
WHERE projectname='$json->{projectname}'
AND workflowname='$newname'};
	my $already_exists = $self->db()->query($query);
	if ( $already_exists ) {
		$self->logError("New name $newname already exists in workflow table");
		return;
	}

	#### SET TABLE AND REQUIRED FIELDS	
	my $table = "workflow";
	my $required_fields = ["username", "projectname", "workflowname"];

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($json, $required_fields);
    $self->logError("undefined values: @$not_defined") and exit if @$not_defined;
	
	#### UPDATE workflow
	my $set_hash = { name => $newname };
	my $set_fields = ["workflowname"];
	my $success = $self->_updateTable($table, $json, $required_fields, $set_hash, $set_fields);
 	$self->logError("Could not rename workflow '$json->{workflowname}' to '$newname' in $table table") and exit if not defined $success;

	#### SET 'workflow' FIELD FOR STAGE AND STAGEPARAMETER TABLES
	$json->{workflow} = $json->{name};
	
	#### UPDATE stage
	$table = "stage";
	$set_hash = { workflow => $newname };
	$set_fields = ["workflow"];
	$required_fields = ["username", "projectname", "name"];
	$self->_updateTable($table, $json, $required_fields, $set_hash, $set_fields);
	
	#### UPDATE stage
	$table = "stageparameter";
	$self->_updateTable($table, $json, $required_fields, $set_hash, $set_fields);
	
	#### UPDATE clusters
	$table = "cluster";
	$set_hash = { workflowname => $newname };
	$set_fields = ["workflowname"];
	$required_fields = ["username", "projectname", "workflowname"];
	$self->_updateTable($table, $json, $required_fields, $set_hash, $set_fields);

	#### RENAME WORKFLOW DIRECTORY
	my $fileroot = $self->util()->getFileroot();
	$self->logDebug("fileroot", $fileroot);
	my $old_filepath = "$fileroot/$json->{projectname}/$json->{workflowname}";
	my $new_filepath = "$fileroot/$json->{projectname}/$json->{newname}";
	if ( $^O =~ /^MSWin32$/ )   {   $old_filepath =~ s/\//\\/g;  }
	$self->logDebug("old_filepath", $old_filepath);
	$self->logDebug("new_filepath", $new_filepath);

	#### CHECK IF WORKFLOW DIRECTORY EXISTS
	$self->logError("Cannot find old workflow directory: $old_filepath") and exit if not -d $old_filepath;
	
	#### RENAME WORKFLOW DIRECTORY
	File::Copy::move($old_filepath, $new_filepath);

	$self->logError("Could not rename directory: $old_filepath to $new_filepath") and exit if not -d $new_filepath;

	$self->logStatus("Successfully renamed workflow $json->{workflowname} to $newname in workflow table");
	
}	#### renameWorkflow

method moveWorkflow {
#### MOVE A WORKFLOW WITHIN A PROJECT
	$self->logDebug("");
	my $workflowobject = $self->{json};
	$self->logDebug("workflowobject", $workflowobject);
	my $newnumber = $workflowobject->{newnumber};	
	my $oldnumber = $workflowobject->{workflownumber};
	$self->logError("oldnumber not defined") and exit if not defined $oldnumber;
	$self->logError("oldnumber == newnumber") and exit if $oldnumber == $newnumber;
	
	my $projectname = $workflowobject->{projectname};
	my $workflowname = $workflowobject->{workflowname};
	my $username = $workflowobject->{username};

	#### CHECK ENTRY IS CORRECT
	my $query = qq{SELECT 1 FROM workflow
WHERE username = '$username'
AND projectname = '$projectname'
AND workflowname = '$workflowname'
AND workflownumber = '$oldnumber'};
	$self->logError("Workflow '$workflowname' (number $oldnumber) not found in project $projectname'") and exit if not $self->db()->query($query);	

	#### GET WORKFLOWS ORDERED BY WORKFLOW NUMBER
	$query = qq{SELECT * FROM workflow
WHERE username = '$username'
AND projectname = '$projectname'
ORDER BY workflownumber};
	my $workflows = $self->db()->queryhasharray($query);

	#### DO RENUMBER
	for ( my $i = 0; $i < @$workflows; $i++ ) {
		$self->logDebug("$$workflows[$i]->{workflowname} - $$workflows[$i]->{workflownumber}");
		my $counter = $i + 1;
		my $number;
		#### SKIP IF BEFORE REORDERED WORKFLOWS
		if ( $counter < $oldnumber and $counter < $newnumber )
		{
			$self->logDebug("Setting counter", $counter);
			$number = $counter;
		}
		#### IF WORKFLOW HAS BEEN MOVED DOWNWARDS, GIVE IT THE NEW INDEX
		#### AND DECREMENT COUNTER FOR SUBSEQUENT WORKFLOWS
		elsif ( $oldnumber < $newnumber ) {
			if ( $counter == $oldnumber ) {
				$self->logDebug("Setting newnumber", $newnumber);
				$number = $newnumber;
			}
			elsif ( $counter <= $newnumber ) {
				$self->logDebug("Setting counter - 1: ", $counter - 1, "");
				$number = $counter - 1;
			}
			else {
				$self->logDebug("Setting counter", $counter);
				$number = $counter;
			}
		}
		#### OTHERWISE, THE WORKFLOW HAS BEEN MOVED UPWARDS SO GIVE IT
		#### THE NEW INDEX AND INCREMENT COUNTER FOR SUBSEQUENT WORKFLOWS
		else {
			if ( $counter < $oldnumber ) {
				$self->logDebug("Setting counter + 1: ", $counter + 1, "");
				$number = $counter + 1;
			}
			elsif ( $oldnumber == $counter ) {
				$self->logDebug("Setting newnumber", $newnumber);
				$number = $newnumber;
			}
			else {
				$self->logDebug("Setting counter", $counter);
				$number = $counter;
			}
		}
		#my $existingnumber= ;
		$query = qq{UPDATE workflow SET workflownumber = $number
WHERE username = '$username'
AND projectname = '$projectname'
AND workflownumber = $$workflows[$i]->{workflownumber}
AND workflowname = '$$workflows[$i]->{workflowname}'};
		$self->logDebug("$query");
		$self->db()->do($query);
	}

	$self->logStatus("Moved workflow $workflowname in project $projectname");
}

=head2

	SUBROUTINE		_defaultWorkflows
	
	PURPOSE

		1. INSERT DEFAULT WORKFLOW INTO workflow TABLE
		
		2. CREATE DEFAULT PROJECT AND WORKFLOW FOLDERS

	INPUT
	
		1. USERNAME
		
		2. SESSION ID
		
	OUTPUT
		
		1. JSON HASH { project1 : { workflow}

=cut

method _defaultWorkflows {
	#### VALIDATE    
	$self->logError("User session not validated") and exit unless $self->validate();

	#### SET DEFAULT WORKFLOW
	my $json = {};
	$json->{username} = $self->username();
	$json->{projectname} = "Project1";
	$json->{workflowname} = "Workflow1";
	$json->{workflownumber} = 1;
	$self->logDebug("json", $json);
	
	#### ADD WORKFLOW
	my $success = $self->_addWorkflow($json);
 	$self->logError("Could not add workflow $json->{workflow} into  workflow table") and exit if not defined $success;

	#### DO QUERY
	my $username = $json->{username};
	$self->logDebug("username", $username);
	my $query = qq{SELECT * FROM workflow
WHERE username='$username'
ORDER BY projectname, workflowname};
	$self->logDebug("$query");	;
	my $workflows = $self->db()->queryhasharray($query);

	return $workflows;
}

=head2

	SUBROUTINE		copyWorkflow
	
	PURPOSE
	
        COPY A WORKFLOW TO ANOTHER (NON-EXISTING) WORKFLOW:
		
			1. UPDATE THE workflow TABLE TO ADD THE NEW WORKFLOW

			3. COPY THE WORKFLOW DIRECTORY TO THE NEW WORKFLOW IF
            
                copyFile IS DEFINED
                
                 echo '{"sourceuser":"admin","targetuser":"syoung","sourceworkflow":"Workflow0","sourceproject":"Project1","targetworkflow":"Workflow9","targetproject":"Project1","username":"syoung","sessionid":"1234567890.1234.123","mode":"copyWorkflow"}' |  ./workflow.cgi
                
=cut

method copyWorkflow {
	my $json 			=	$self->json();
 	$self->logDebug("Common::copyWorkflow()");
	$self->logError("No data provided") if not defined $json;
	
	my $sourceuser     	= $json->{sourceuser};
	my $targetuser     	= $json->{targetuser};
	my $sourceproject  	= $json->{sourceproject};
	my $sourceworkflow 	= $json->{sourceworkflow};
	my $targetproject  	= $json->{targetproject};
	my $targetworkflow 	= $json->{targetworkflow};
	my $copyfiles      	= $json->{copyfiles};
	my $date						= $json->{date};

	$self->logDebug("sourceuser", $sourceuser);
	$self->logDebug("targetuser", $targetuser);
	$self->logDebug("sourceworkflow", $sourceworkflow);
	$self->logDebug("targetworkflow", $targetworkflow);

	$self->logError("User not validated: $targetuser") and exit if not $self->validate();
	$self->logError("targetworkflow not defined: $targetworkflow") and exit if not defined $targetworkflow or not $targetworkflow;

	my $can_copy;
	$can_copy = 1 if $sourceuser eq $targetuser;
	$can_copy = $self->canCopy($sourceuser, $sourceproject, $targetuser) if $sourceuser ne $targetuser;
	$self->logDebug("can_copy", $can_copy);

	$self->logError("Insufficient privileges for user: $targetuser") and exit if not $can_copy;

	#### CHECK IF WORKFLOW ALREADY EXISTS
	my $query = qq{SELECT 1
FROM workflow
WHERE username = '$targetuser'
AND projectname = '$targetproject'
AND workflowname = '$targetworkflow'};
	$self->logDebug("$query");
	my $workflow_exists = $self->db()->query($query);
	$self->logError("Workflow already exists: $targetworkflow") and exit if $workflow_exists;
	
	#### GET SOURCE PROJECT
	$query = qq{SELECT *
FROM workflow
WHERE username = '$sourceuser'
AND projectname = '$sourceproject'
AND workflowname = '$sourceworkflow'};
	$self->logDebug("$query");
	my $workflowobject = $self->db()->queryhash($query);
  $self->logError("Source workflow does not exist: $targetworkflow") and exit if not defined $workflowobject;
	
	#### SET PROVENANCE
	$workflowobject = $self->setProvenance($workflowobject, $date);
	
	#### SET WORKFLOW NUMBER
	$query = qq{SELECT MAX(workflownumber)
FROM workflow
WHERE username = '$targetuser'
AND projectname = '$targetproject'};
	$self->logDebug("$query");
	my $workflownumber = $self->db()->query($query);
	$workflownumber = 0 if not defined $workflownumber;
	$workflownumber++;
	$workflowobject->{number} = $workflownumber;
    
	#### COPY WORKFLOW (AND STAGES, STAGE PARAMETERS, VIEW, ETC.)
	$self->_copyWorkflow($workflowobject, $targetuser, $targetproject, $targetworkflow, $date);
	
	#### COPY FILES IF FLAGGED BY copyfiles 
	if ( defined $copyfiles and $copyfiles ){
		#### SET DIRECTORIES
		my $aguadir = $self->conf()->getKey("core:AGUADIR");
		my $userdir = $self->conf()->getKey("core:USERDIR");
		my $sourcedir = "$userdir/$sourceuser/$aguadir/$sourceproject/$sourceworkflow";
		my $targetdir = "$userdir/$targetuser/$aguadir/$targetproject/$targetworkflow";
		$self->logDebug("sourcedir", $sourcedir);
		$self->logDebug("targetdir", $targetdir);

		#### COPY DIRECTORY
		my $copy_result = $self->copyFilesystem($targetuser, $sourcedir, $targetdir);
		$self->logStatus("Copied to $targetworkflow") and exit if $copy_result;
		$self->logStatus("Could not copy to '$targetworkflow");
	}
	
	$self->logStatus("Completed copy to $targetworkflow");
}

method _copyWorkflow ($workflowobject, $targetuser, $targetproject, $targetworkflow, $date) {    
	my $sourceuser      =   $workflowobject->{username};
	my $sourceworkflow  =   $workflowobject->{name};
	my $sourceproject   =   $workflowobject->{projectname};

	$self->logDebug("targetuser", $targetuser);
	$self->logDebug("targetworkflow", $targetworkflow);
	$self->logDebug("targetproject", $targetproject);

	$self->logDebug("sourceuser", $sourceuser);
	$self->logDebug("sourceproject", $sourceproject);
	$self->logDebug("workflowobject", $workflowobject);

	#### CREATE PROJECT DIRECTORY
	my $aguadir = $self->conf()->getKey("core:AGUADIR");
	my $userdir = $self->conf()->getKey("core:USERDIR");
	my $targetdir = "$userdir/$targetuser/$aguadir/$targetproject/$targetworkflow";
	$self->logDebug("targetdir", $targetdir);
	File::Path::mkpath($targetdir);

	#### SET PROVENANCE
	$workflowobject = $self->setProvenance($workflowobject, $date);

	#### INSERT COPY OF WORKFLOW INTO TARGET 
	$workflowobject->{username} = $targetuser;
	$workflowobject->{projectname} = $targetproject;
	$workflowobject->{workflowname} = $targetworkflow;
	$self->insertWorkflow($workflowobject);

	my $query;
	#### COPY STAGES
	$query = qq{SELECT * FROM stage
WHERE username='$sourceuser'
AND projectname='$sourceproject'
AND workflowname='$sourceworkflow'};
	$self->logDebug("$query"); ;
	my $stages = $self->db()->queryhasharray($query);
	$stages = [] if not defined $stages;
	$self->logDebug("No. stages: " . scalar(@$stages));
	foreach my $stage ( @$stages ) {
		$stage->{username} = $targetuser;
		$stage->{projectname} = $targetproject;
		$stage->{workflow} = $targetworkflow;
	}
	$self->insertStages($stages);

	#### COPY STAGE PARAMETERS
	foreach my $stage ( @$stages ) {
	my $query = qq{SELECT * FROM stageparameter
WHERE username='$sourceuser'
AND projectname='$sourceproject'
AND workflowname='$sourceworkflow'
AND appnumber='$stage->{number}'};
		$self->logDebug("$query");
		my $stageparams = $self->db()->queryhasharray($query);
		$stageparams = [] if not defined $stageparams;
		$self->logDebug("No. stageparams: " . scalar(@$stageparams));
		foreach my $stageparam ( @$stageparams ) {
			my $sourcedir = "$stageparam->{projectname}/$stageparam->{workflow}";
			my $targetdir = "$targetproject/$targetworkflow";
			$stageparam->{value} =~ s/$sourcedir/$targetdir/g;
			$stageparam->{username} = $targetuser;
			$stageparam->{projectname} = $targetproject;
			$stageparam->{workflowname} = $targetworkflow;
		}
		$self->insertStageParameters($stageparams);
	}
	
	#### COPY INFORMATION IN view TABLE
	$query = qq{SELECT * FROM view
WHERE username='$sourceuser'
AND projectname='$sourceproject'};
	$self->logDebug("$query");
	my $views = $self->db()->queryhasharray($query);
	$views = [] if not defined $views;
	$self->logDebug("No. views: " . scalar(@$views));
	foreach my $view ( @$views ) {
		$view->{username} = $targetuser;
		$view->{projectname} = $targetproject;
	}
	$self->insertViews($views); 
}

method copyFilesystem ($username, $source, $target) {
#### COPY DIRECTORY
	require File::Copy::Recursive;
	$self->logDebug("Copying...");
	$self->logDebug("FROM", $source);
	$self->logDebug("TO", $target);
	my $result = File::Copy::Recursive::rcopy($source, $target);
	$self->logDebug("copy result", $result);
    
	return $result;
}

=head2

	SUBROUTINE		copyProject
	
	PURPOSE
	
		COPY A PROJECT TO A (NON-EXISTING) DESTINATION PROJECT:
       
			1. ADD PROJECT TO project TABLE
            
            2. ADD ANY WORKFLOWS TO THE workflow TABLE
			
			2. OPTIONALLY, COPY THE PROJECT DIRECTORY

	EXAMPLE
	
echo '{"sourceuser":"admin","targetuser":"syoung","sourceproject":"Project1","targetproject":"Project1","username":"syoung","sessionid":"1234567890.1234.123","mode":"copyProject"}' |  ./workflow.cgi
                
=cut

method copyProject {
	my $json 		=	$self->json();
 	$self->logDebug("Common::copyProject()");
	$self->logError("No data provided") if not defined $json;
	
	my $sourceuser 		= $json->{sourceuser};
	my $targetuser 		= $json->{targetuser};
	my $sourceproject = $json->{sourceproject};
	my $targetproject = $json->{targetproject};
	my $copyfiles 		= $json->{copyfiles};
	
	$self->logError("User not validated: $targetuser") and exit if not $self->validate();
	
	my $can_copy = $self->projectPrivilege($sourceuser, $sourceproject, $targetuser, "groupcopy");
	$self->logError("Insufficient privileges for user: $targetuser") and exit if not $can_copy;

	#### EXIT IF TARGET PROJECT ALREADY EXISTS IN project TABLE
	my $query = qq{SELECT 1
FROM project
WHERE username = '$targetuser'
AND projectname = '$targetproject'};
	$self->logDebug("$query");
	my $exists = $self->db()->query($query);
	$self->logError("Project already exists: $targetproject ") and exit if $exists;

	my $success = $self->_copyProject($json);
	$self->logError("Failed to copy project $sourceproject to $targetproject") and exit if not $success;
	
	$self->logStatus("Copied to project $sourceproject to $targetproject") ;    
}

method _copyProject ($data) {
	$self->logDebug("data", $data);
	
	my $sourceuser 		= $data->{sourceuser};
	my $targetuser 		= $data->{targetuser};
	my $sourceproject = $data->{sourceproject};
	my $targetproject = $data->{targetproject};
	my $copyfiles 		= $data->{copyfiles};
	
	#### CONFIRM THAT SOURCE PROJECT EXISTS IN project TABLE
	my $query = qq{SELECT *
FROM project
WHERE username = '$sourceuser'
AND projectname = '$sourceproject'};
	$self->logDebug("$query");
	my $projectobject = $self->db()->queryhash($query);
	$self->logDebug("projectObject", $projectobject);
	$self->logError("Source project does not exist: $sourceproject") and exit if not defined $projectobject;
	
	#### SET PROVENANCE
	my $date = $data->{date};
	$projectobject = $self->setProvenance($projectobject, $date);
	
	#### SET TARGET VARIABLES
	$projectobject->{username} 	= 	$targetuser;
	$projectobject->{projectname}		=	$targetproject;

	#### DO ADD
	$self->logDebug("Doing _addToTable(table, json, required_fields)");
	my $required_fields = [ "username", "projectname" ];
	my $table = "project";	
	my $success = $self->_addToTable($table, $projectobject, $required_fields);	
	$self->logDebug("_addToTable(stage info) success", $success);
    $self->logError("Could not insert project: $targetproject") and exit if not $success;

	#### GET SOURCE WORKFLOW INFORMATION
	$query = qq{SELECT * FROM workflow
WHERE username='$sourceuser'
AND projectname='$sourceproject'};
	$self->logDebug("$query");
	my $workflowObjects = $self->db()->queryhasharray($query);
	$self->logDebug("No. workflows: " . scalar(@$workflowObjects));

	#### COPY SOURCE WORKFLOW TO TARGET WORKFLOW
	#### COPY ALSO STAGE, STAGEPARAMETER, VIEW AND REPORT INFO
	foreach my $workflowObject ( @$workflowObjects ) {
		$self->_copyWorkflow($workflowObject, $targetuser, $targetproject, $workflowObject->{name}, $date);
	}
	
	#### CREATE PROJECT DIRECTORY
	my $aguadir = $self->conf()->getKey("core:AGUADIR");
	my $userdir = $self->conf()->getKey("core:USERDIR");
	my $targetdir = "$userdir/$targetuser/$aguadir/$targetproject";
	File::Path::mkpath($targetdir);

	#### COPY FILES AND SUBDIRS IF FLAGGED BY copyfiles
	if ( defined $copyfiles and $copyfiles ) {
		#### SET DIRECTORIES
		$self->logDebug("aguadir", $aguadir);
		my $sourcedir = "$userdir/$sourceuser/$aguadir/$sourceproject";
		
		#### COPY DIRECTORY
		my $copy_success = $self->copyFilesystem($sourcedir, $targetdir);
		$copy_success = 0 if not defined $copy_success;
		$self->logError("Could not copy to '$targetproject") and exit if not $copy_success;
	}
	
	return 1;    
}

method setProvenance ($object, $date) {
	#### GET PROVENANCE
	require JSON; 
	my $jsonparser = new JSON;
	my $provenance;
	$self->logDebug("object->{provenance}", $object->{provenance});
	$provenance = $jsonparser->allow_nonref->decode($object->{provenance}) if $object->{provenance};
	$provenance = [] if not $object->{provenance};
	
	#### SET PROVENANCE
	my $username = $self->username();
	delete $object->{provenance};
	push @$provenance, {
		copiedby	=>	$username,
		date			=>	$date,
		original	=>	$object
	};
	my $provenancestring = $jsonparser->encode($provenance);
	$self->logDebug("provenancestring", $provenancestring);
	$object->{provenance} = $provenancestring;
	
	return $object;
}

method insertViews ($hasharray) {
	$self->logDebug("hasharray", $hasharray);
    
	#### SET TABLE AND REQUIRED FIELDS	
	my $table       =   "view";
	my $required_fields = ["username", "projectname"];
	my $inserted_fields = $self->db()->fields($table);

	foreach my $hash ( @$hasharray ) {    
		#### CHECK REQUIRED FIELDS ARE DEFINED
		my $not_defined = $self->db()->notDefined($hash, $required_fields);
		$self->logError("undefined values: @$not_defined") and exit if @$not_defined;

		#### DO ADD
		$self->logDebug("Doing _addToTable(table, json, required_fields)");
		my $success = $self->_addToTable($table, $hash, $required_fields, $inserted_fields);	
		$self->logDebug("_addToTable(stage info) success", $success);
	}
}

method insertReports ($hasharray) {
#### SET TABLE AND REQUIRED FIELDS	
	my $table       =   "report";
	my $required_fields = ["username", "projectname", "workflowname", "workflownumber"];
	my $inserted_fields = $self->db()->fields($table);

	foreach my $hash ( @$hasharray ) {    
		#### CHECK REQUIRED FIELDS ARE DEFINED
		my $not_defined = $self->db()->notDefined($hash, $required_fields);
		$self->logError("undefined values: @$not_defined") and exit if @$not_defined;

		#### DO ADD
		$self->logDebug("Doing _addToTable(table, json, required_fields)");
		my $success = $self->_addToTable($table, $hash, $required_fields, $inserted_fields);	
		$self->logDebug("_addToTable(stage info) success", $success);
	}
}

method insertStageParameters ($stageparameters) {
	#### SET TABLE AND REQUIRED FIELDS	
	my $table       =   "stageparameter";
	my $required_fields = ["username", "projectname", "workflowname", "appname", "appnumber", "paramname"];
	my $inserted_fields = $self->db()->fields($table); 
	foreach my $stageparameter ( @$stageparameters ) {    
		#### CHECK REQUIRED FIELDS ARE DEFINED
		my $not_defined = $self->db()->notDefined($stageparameter, $required_fields);
		$self->logError("undefined values: @$not_defined") and exit if @$not_defined;

		#### DO ADD
		$self->logDebug("Doing _addToTable(table, json, required_fields)");
		my $success = $self->_addToTable($table, $stageparameter, $required_fields, $inserted_fields);	
		$self->logDebug("_addToTable(stage info) success", $success);
	}
}

method insertStages ($stages) {
#### SET TABLE AND REQUIRED FIELDS	
	my $table       =   "stage";
	my $required_fields = ["username", "projectname", "workflow", "appnumber", "appname"];
	my $inserted_fields = $self->db()->fields($table);    
    
	foreach my $stage ( @$stages ) {    
		#### CHECK REQUIRED FIELDS ARE DEFINED
		my $not_defined = $self->db()->notDefined($stage, $required_fields);
		$self->logError("undefined values: @$not_defined") and exit if @$not_defined;

		#### DO ADD
		$self->logDebug("Doing _addToTable(table, json, required_fields)");
		my $success = $self->_addToTable($table, $stage, $required_fields, $inserted_fields);	
		$self->logDebug("_addToTable(stage info) success", $success);
	}
}

method insertWorkflow ($workflowobject) {
#### SET TABLE AND REQUIRED FIELDS	
	my $table       		=   "workflow";
	my $required_fields = 	["username", "projectname", "workflowname", "workflownumber"];
	my $inserted_fields = 	$self->db()->fields($table);

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($workflowobject, $required_fields);
	$self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	#### DO ADD
	$self->logDebug("Doing _addToTable(table, json, required_fields)");
	my $success = $self->_addToTable($table, $workflowobject, $required_fields, $inserted_fields);	
	$self->logDebug("_addToTable(stage info) success", $success);
}

method workflowIsRunning ($username, $projectname, $workflowname) {
	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowname", $workflowname);

	my $query = qq{SELECT 1 from stage
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
AND status='running'
};
	$self->logDebug("query", $query);
	my $result =  $self->db()->query($query);
	$self->logDebug("Returning result", $result);
	
	return $result
}






1;
