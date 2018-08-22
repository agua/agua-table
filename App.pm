package Table::App;
use Moose::Role;
use Method::Signatures::Simple;

=head2

	PACKAGE		Table::App
	
	PURPOSE
	
		app TABLE METHODS
		
=cut

method getAppHeadings {
	$self->logDebug("");

	#### VALIDATE    
  my $username = $self->username();
	$self->logError("User $username not validated") and return unless $self->validate($username);

	my $headings = {
		leftPane 	=>	["Parameters", "App", "Packages"],
		middlePane 	=>	["Packages", "Parameters", "App"],
		rightPane 	=>	["App", "Packages", "Parameters"]
	};
	$self->logDebug("headings", $headings);
	
    return $headings;
}

method getApps {
  my $username	= 	$self->username();
	my $agua 		= 	$self->conf()->getKey("core:AGUAUSER");
	
  my $query = qq{SELECT * FROM app
WHERE owner = '$username'
OR owner='$agua'
ORDER BY owner, packagename, apptype, appname};
	$self->logDebug("query", $query);
    my $apps = $self->db()->queryhasharray($query) || [];

	if ( not $self->isAdminUser($username)) {
		my $adminapps = $self->getAdminApps();
		@$apps = (@$apps, @$adminapps);
	}
	
	return $apps;
}

method getAdminApps {
#### GET ONLY 'PUBLIC' APPS OWNED BY ADMIN USER
	$self->logDebug("");

	#### GET ADMIN USER'S PUBLIC APPS
	my $admin = $self->conf()->getKey("core:ADMINUSER");
	my $query = qq{SELECT app.* FROM app, package
WHERE app.owner = '$admin'
AND app.owner = package.username
AND package.privacy='public'
ORDER BY packagename, apptype, appname};
    my $adminapps = $self->db()->queryhasharray($query) || [];
	$self->logDebug("adminapps", $adminapps);
	
	return $adminapps;
}

method deleteApp {
=head2

    SUBROUTINE:     deleteApp
    
    PURPOSE:

        VALIDATE THE admin USER THEN DELETE AN APPLICATION
		
=cut
	my $data = $self->json()->{data};
	$data->{owner} = $self->json()->{username};
	$self->logDebug("data", $data);

	my $success = $self->_removeApp($data);
	return if not defined $success;

	$self->logStatus("Deleted application $data->{appname}") if $success;
	$self->logError("Could not delete application $data->{appname} from the apps table") if not $success;
	return;
}

method _removeApp ( $data ) {
	$self->logDebug("data", $data);
	#$self->logDebug("self", $self);
	
	#### SHIM
	$data->{name} = $data->{appname} if not defined $data->{name};
	
	my $table = "app";
	my $required = ["owner", "packagename", "appname", "apptype"];
	
	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $notdefined = $self->db()->notDefined($data, $required);
	$self->logDebug("notdefined", $notdefined);
    $self->logError("undefined values: @$notdefined") and return if @$notdefined;

	#### REMOVE
	return $self->_removeFromTable($table, $data, $required);
}

method saveApp {
=head2

    SUBROUTINE:     saveApp
    
    PURPOSE:

        SAVE APPLICATION INFORMATION
		
=cut

	#### VALIDATE    
  my $username = $self->username();
	$self->logError("User $username not validated") and return unless $self->validate($username);
	
	#### GET DATA FOR PRIMARY KEYS FOR apps TABLE:
	####    name, type, location
	my $json		=	$self->json();
	$self->logDebug("json", $json);
	my $data = $json->{data};
	my $appname = $data->{appname};
	my $apptype = $data->{apptype};
	my $location = $data->{location};
	$self->logDebug("appname", $appname);
	$self->logDebug("apptype", $apptype);
	$self->logDebug("location", $location);
	
	#### CHECK INPUTS
	$self->logError("appname not defined or empty") and return if not defined $appname or $appname =~ /^\s*$/;
	$self->logError("apptype not defined or empty") and return if not defined $apptype or $apptype =~ /^\s*$/;
	$self->logError("location not defined or empty") and return if not defined $location or $location =~ /^\s*$/;
	
	my $success	=	$self->_saveApp($data);
	$self->logDebug("success", $success);
	$self->logError("Could not insert application $appname into app table ") and return if not $success;

	$self->logStatus("Inserted application $appname into app table");
	return;
}

method _saveApp ( $data ) {
	$self->logDebug("data", $data);
		
	#### GET APP IF ALREADY EXISTS
	my $table = "app";
	my $fields = ["owner", "packagename", "appname", "apptype"];
	my $where = $self->db()->where($data, $fields);
	my $query = qq{SELECT * FROM $table $where};
	$self->logDebug("query", $query);
	my $app = $self->db()->queryhash($query);
	$self->logDebug("app", $app);
	
	#### REMOVE APP IF EXISTS
	if ( defined $app ) {
		$self->_removeApp($data);

		#### ... AND COPY OVER DATA ONTO APP
		foreach my $key ( keys %$data ) {
			$app->{$key} = $data->{$key};
		}
		$self->logDebug("app", $app);		

		#### ADD APP MODIFIED WITH DATA
		my $success = $self->_addApp($app);
		return if not defined $success;
	}
	
	#### ADD DATA
	return $self->_addApp($data);
}

method _addApp ( $data ) {
	$self->logNote("data", $data);
	
	my $owner 	=	$data->{owner};
	my $name 	=	$data->{name};

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $table = "app";
	my $required_fields = ["owner", "package", "appname", "apptype"];
	my $not_defined = $self->db()->notDefined($data, $required_fields);
    $self->logError("undefined values: @$not_defined") and return if @$not_defined;
		
	#### DO ADD
	return $self->_addToTable($table, $data, $required_fields);	
}

method saveParameter {
=head2

    SUBROUTINE:     saveParameter
    
    PURPOSE:

        VALIDATE THE admin USER THEN SAVE APPLICATION INFORMATION
		
=cut
	$self->logDebug("");
	my $json			=	$self->json();

	#### GET DATA FOR PRIMARY KEYS FOR parameters TABLE:
  my $username 		= 	$self->username();
	my $data 				= 	$json->{data};
	my $appname 		= 	$data->{appname};
	my $paramname 	= 	$data->{paramname};
	my $paramtype 	= 	$data->{paramtype};

	#### SET owner AS USERNAME IN data
	$data->{owner} = $username;
	
	#### CHECK INPUTS
	$self->logError("appname not defined or empty") and return if not defined $appname or $appname =~ /^\s*$/;
	$self->logError("paramname not defined or empty") and return if not defined $paramname or $paramname =~ /^\s*$/;
	$self->logError("paramtype not defined or empty") and return if not defined $paramtype or $paramtype =~ /^\s*$/;
	
	$self->logDebug("paramname", $paramname);
	$self->logDebug("paramtype", $paramtype);
	$self->logDebug("appname", $appname);

	my $success = $self->_addParameter($data); 
	if ( $success != 1 ) {
		$self->logError("Could not insert parameter $paramname into app $appname");
	}
	else {
		$self->logStatus("Inserted parameter $paramname into app $appname");
	}

	return;
}

method _addParameter ( $data ) {
	my $username	=	$data->{username};
	my $appname		=	$data->{appname};
	my $paramname	=	$data->{paramname};

	my $table = "parameter";
	my $required = ["owner", "appname", "paramname", "paramtype"];
	my $updates = ["version", "status"];

	#### REMOVE IF EXISTS ALREADY
	my $success = $self->_removeFromTable($table, $data, $required);
	$self->logNote("Deleted app success") if $success;
		
	#### INSERT
	my $fields = $self->db()->fields('parameter');
	my $insert = $self->db()->insert($data, $fields);
	my $query = qq{INSERT INTO $table VALUES ($insert)};
	$self->logNote("query", $query);	
	return $self->db()->do($query);
}

method deleteParameter {
=head2

    SUBROUTINE:     deleteParameter
    
    PURPOSE:

        VALIDATE THE admin USER THEN DELETE AN APPLICATION
		
=cut
	
	#### GET DATA 
	my $json	=	$self->json();
	my $data 	= $json->{data};

	#### REMOVE
	my $success = $self->_removeParameter($data);
	$self->logStatus("Deleted parameter $data->{name}") and return if defined $success and $success;

	$self->logError("Could not delete parameter $data->{name}");
	return;
}

method _removeParameter ( $data ) {
	#$self->logDebug("data", $data);

	#### SET DEFAULT TYPE
	$data->{paramtype} = "input" if not defined $data->{paramtype};
	
	my $table = "parameter";
	my $required_fields = ["owner", "appname", "paramname", "paramtype"];

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($data, $required_fields);
    $self->logError("undefined values: @$not_defined") and return if @$not_defined;
	
	#### REMOVE IF EXISTS ALREADY
	$self->_removeFromTable($table, $data, $required_fields);
}




1;