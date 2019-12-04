package Table::Parameter;
use Moose::Role;
use Method::Signatures::Simple;

=head2

	PACKAGE		Table::Parameter
	
	PURPOSE
	
		parameter AND stageparameter TABLE METHODS
		
=cut

##############################################################################
#				STAGEPARAMETER METHODS
##############################################################################

#### RETURN AN ARRAY OF HASHES
method getParametersByStage ( $data ) {
	$self->logNote("data", $data);

	my $required = ["username", "projectname", "workflowname", "appname", "appnumber"];
	my $where = $self->db()->where($data, $required);
	my $query = qq{SELECT * FROM stageparameter
$where
ORDER BY ordinal};
	#$self->logDebug("$query");

	my $parameters = $self->db()->queryhasharray($query);
	$parameters = [] if not defined $parameters;
	#$self->logDebug("parameters", $parameters);

	return $parameters;
}

#### RETURN AN ARRAY OF HASHES
method getParametersByApp ( $data ) {
	$self->logNote("data", $data);
	
	my $required = ["username", "packagename", "installdir", "appname"];
	my $where = $self->db()->where($data, $required);
	my $query = qq{SELECT * FROM parameter
$where};
	$self->logDebug("query", $query);
	
	my $parameters = $self->db()->queryhasharray($query);
	$parameters = [] if not defined $parameters;
	$self->logDebug("no. parameters", scalar(@$parameters)) if defined $parameters;
	$self->logDebug("parameters not defined") if not defined $parameters;
	
	return $parameters;
}

#### RETURN AN ARRAY OF HASHES
method getStageParameters ( $username ) {
	$self->logDebug("username", $username);

	#### SET username IF NOT DEFINED
	$username = $self->username() if not defined $username;

  #### VALIDATE    
  $self->logError("User session not validated") and return unless $self->validate();

	my $query = qq{SELECT * FROM stageparameter
WHERE username='$username'
ORDER BY projectname, workflowname, appnumber, paramtype, paramname};
	$self->logDebug("$query");
	my $stageparameters = $self->db()->queryhasharray($query);
	$stageparameters = [] if not defined $stageparameters;

	$self->logDebug("stageparameters", $stageparameters);
	$self->logDebug("no. stageparameters", scalar(@$stageparameters));
	
	$self->logDebug("username", $username);
	my $fileroot = $self->util()->getFileroot($username);
	$self->logDebug("fileroot", $fileroot);
	
	foreach my $stageparameter ( @$stageparameters ) {
		my $valuetype = $stageparameter->{valuetype};
		$self->logDebug("valuetype", $valuetype);
		my $name = $stageparameter->{name};
		$self->logDebug("name", $name);

		next if not $valuetype !~ /^file$/ and not $valuetype !~ /^directory$/;
		my $value = $stageparameter->{value};
		next if not defined $value or not $value;
		
		if ( $valuetype eq "file" or $valuetype eq "directory" ) {
			my $filepath = "$fileroot/$value";
			$self->logDebug("filepath", $filepath);
			$stageparameter->{fileinfo} = $self->getFileinfo($filepath);
			$self->logDebug("stageparameter->{fileinfo}", $stageparameter->{fileinfo});
		}
	}
	
	return $stageparameters;
}

#### ADD A PARAMETER TO THE stageparameter TABLE
method _addStageParameter ( $data ) {
 	$self->logDebug("data", $data);

	#### SET TABLE AND REQUIRED FIELDS	
	my $table = "stageparameter";
	my $required_fields = ["username", "projectname", "workflowname", "appname", "appnumber", "paramname", "paramnumber"];
	my $fields = $self->db()->fields ( $table );

	#### DEFAULT PARAMTYPE IS 'input'
	$data->{paramtype}	=	"input" if not defined $data->{paramtype};

	#### ADD DEFAULTS
	$data->{submit}		=	0 if not defined $data->{submit};
	$data->{locked}		=	0 if not defined $data->{locked};
	$data->{queued}		=	0 if not defined $data->{queued};
	$data->{chained}	=	0 if not defined $data->{chained};
	
	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($data, $required_fields);
  $self->logError("undefined values: @$not_defined") and return if @$not_defined;

	#### ADD ALL FIELDS OF THE PASSED STAGE PARAMETER TO THE TABLE
 	$self->logDebug("Doing addToTable(table, data, required_fields)");
	return $self->_addToTable($table, $data, $required_fields);	
}

method _deleteStageParameter ( $data ) {
 	$self->logDebug("data", $data);	
	
	#### SET TABLE AND REQUIRED FIELDS	
	my $table = "stageparameter";
	my $required_fields = ["username", "projectname", "workflowname", "appname", "appnumber", "paramname", "paramnumber"];

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($data, $required_fields);
  $self->logError("undefined values: @$not_defined") and return if @$not_defined;

	#### REMOVE IF EXISTS ALREADY
 	$self->logDebug("Doing _removeFromTable(table, data, required_fields)");
	return $self->_removeFromTable($table, $data, $required_fields);
}

##############################################################################
#				PARAMETER METHODS
##############################################################################
method getParameters {
  my $username	= 	$self->username();
	my $admin 		= 	$self->conf()->getKey("core:ADMINUSER");
	my $agua 		= 	$self->conf()->getKey("core:AGUAUSER");

	#### GET USER'S OWN APPS	
  my $query = qq{SELECT * FROM parameter
WHERE owner = '$username'
OR owner='$admin'
OR owner='$agua'
ORDER BY owner, packagename, apptype, appname, name};
  my $parameters = $self->db()->queryhasharray($query);
	$parameters = [] if not defined $parameters;

	return $parameters;
}



1;