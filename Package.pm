package Table::Package;
use Moose::Role;
use Method::Signatures::Simple;
use JSON;

=head2

	PACKAGE		Table::Package
	
	PURPOSE
	
		SET DEFAULT VALUES FOR INITIAL AGUA INSTALL

=cut

#### DEFAULT WORKFLOW AND APP PACKAGES

method addPackage () {
  my $username 	= 	$self->username();
	my $json		=	$self->json();
	$self->logDebug("username", $username);

	#### PRIMARY KEYS FOR package TABLE: packagename, type, location
	my $data 					= $json->{data};
	my $packagename 	= $data->{packagename};
	my $version 			= $data->{version};
	$self->logDebug("data", $data);

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $required_fields = ['packagename', 'version', 'opsdir', 'installdir'];	
	my $not_defined = $self->db()->notDefined($data, $required_fields);
	$self->logError("undefined values: @$not_defined") and exit if @$not_defined;
	
	#### REMOVE IF EXISTS
	$self->_removePackage($data);
	
	#### ADD DATA
	my $success = $self->_addPackage($data);
	$self->logStatus("Could not add package $package") and exit if not $success;
 	$self->logStatus("Added package $package") if $success;
}

method _addPackage ($data) {
	$self->logDebug("data", $data);
	my $datetime		=	$self->db()->query("SELECT NOW()");
	$data->{datetime}	=	$datetime;

	my $table = "package";
	my $required_fields = ['owner', 'username', 'packagename', 'version', 'installdir'];
	
	return $self->_addToTable($table, $data, $required_fields);
}

=head2

    SUBROUTINE:     removePackage
    
    PURPOSE:

        VALIDATE THE admin USER THEN DELETE A PACKAGE
		
=cut

method removePackage {
	my $json					=	$self->json();
  my $username 			= $self->username();
	$self->logDebug("username", $username);

	#### PRIMARY KEYS FOR package TABLE: package, type, location
	my $data 					= $json->{data};
	my $packagename 	= $data->{package};
	my $version 			= $data->{version};
	$self->logDebug("packagename", $packagename);

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $required_fields = ['owner','username','packagename', 'version'];	
	my $not_defined = $self->db()->notDefined($data, $required_fields);
	$self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	my $success = $self->_removePackage($data);
	if ( $success == 1 ) {
		$self->logStatus("Removed package $packagename (version $version)");
	}
	else {
		$self->logError("Could not remove package $packagename (version $version)");
	}
}

method _removePackage ($data) {
	$self->logDebug("data", $data);
	
	#### REMOVE APPS
	my $table = "app";
	my $appdata = $data;
	$appdata->{owner} = $appdata->{username};
	my $required_fields = ['owner', 'packagename', 'version'];
	$self->_removeFromTable($table, $appdata, $required_fields);
	
	#### REMOVE PARAMETERS
	$table = "parameter";
	$required_fields = ['owner', 'packagename', 'version'];
	
	#### REMOVE PACKAGE
	$table = "package";
	$required_fields = ['owner', 'username', 'packagename', 'version'];

	return $self->_removeFromTable($table, $data, $required_fields);
}

1;

