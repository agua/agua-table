package Table::Project;
use Moose::Role;
use Method::Signatures::Simple;

use File::Path;

=head2

	PACKAGE		Table::Project
	
	PURPOSE
	
		project TABLE METHODS
		
=cut

method isProject ( $username, $projectname ) {
    $self->logDebug("username", $username);
    $self->logDebug("projectname", $projectname);

    my $project = $self->getProject( $username, $projectname );
    $self->logDebug("project", $project);

    return 0 if not $project or not defined $project->{projectname};
    return 1;
}

method getProject ( $username, $projectname ) {
	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	my $query = qq{SELECT * FROM project
WHERE username='$username'
AND projectname='$projectname'};

	return $self->db->queryhash( $query );
}

method setProjectStatus ($username, $projectname, $status) {
	my $data	=	{
		username			=>	$username,
		projectname		=>	$projectname
	};
	
	#### CHECK REQUIRED FIELDS
	my $table = "project";
	my $required_fields = ["username", "projectname"];
	my $not_defined = $self->db()->notDefined($data, $required_fields);
  $self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	#### UPDATE
	my $query	=	qq{UPDATE project
SET status='$status'
WHERE username='$username'
AND projectname='$projectname'};
	$self->logDebug("query", $query);
	my $success = $self->db()->do($query);	
	$self->logDebug("success", $success);
	
	return $success;	
}

method saveProject {
=head2

	SUBROUTINE		saveProject
	
	PURPOSE

		ADD A PROJECT TO THE project TABLE
        
=cut

    my $json 		=	$self->json();

 	$self->logDebug("Common::saveProject()");
	my $success = $self->_removeProject($json);
	$self->logStatus("Could not remove project $json->{project} from project table") if not $success;
	$success = $self->_addProject($json);	
	$self->logStatus("Successful insert of project $json->{project} into project table") if $success;
}

method addProject {
=head2

	SUBROUTINE		addProject
	
	PURPOSE

		ADD A PROJECT TO THE project TABLE
        
=cut

  my $data 		=	$self->json();

 	$self->logDebug("Common::addProject()");

	#### REMOVE IF EXISTS ALREADY
	$self->_removeProject($data);

	my $success = $self->_addProject($data);	
	$self->logStatus("Created/updated project $data->{name}") if $success;
}

method _addProject ($data) {
=head2

	SUBROUTINE		_addProject
	
	PURPOSE

		ADD A PROJECT TO THE project TABLE
        
=cut

 	$self->logDebug("data", $data);

	#### SET TABLE AND REQUIRED FIELDS	
	my $table = "project";
	my $required_fields = ["username", "projectname"];
	my $fields = $self->db()->fields( $table );
 	$self->logDebug("data->{username}", $data->{username});
 	$self->logDebug("data->{projectname}", $data->{projectname});

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->db()->notDefined($data, $required_fields);
    $self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	#### DO ADD
	my $success = $self->_addToTable($table, $data, $required_fields, $fields );	
 	$self->logError("Could not add project $data->{project} into project $data->{projectname} in project table") and exit if not defined $success;

	#### ADD THE PROJECT DIRECTORY TO THE USER'S agua DIRECTORY
  my $username = $data->{'username'};
	my $fileroot = $self->util()->getFileroot($username);
	$self->logDebug("fileroot", $fileroot);

	#### CREATE
	my $directory = "$fileroot/$data->{projectname}";
	if ( not -d $directory ) {
		$self->logDebug("Creating directory", $directory);
		File::Path::mkpath( $directory );
		return 0 if not -d $directory;
	}
	
	return 1;
}

method _removeProject ($data) {
=head2

	SUBROUTINE		_removeProject
	
	PURPOSE

		REMOVE A PROJECT FROM THE project, workflow, groupmember, stage AND

		stageparameter TABLES, AND REMOVE THE PROJECT FOLDER AND DATA FILES
      
=cut

 	$self->logDebug("data", $data);

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $required_fields = ["username", "projectname"];
	my $not_defined = $self->db()->notDefined($data, $required_fields);
  $self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	#### REMOVE FROM project
	my $table = "project";
	return $self->_removeFromTable($table, $data, $required_fields);
}

method removeProject {
=head2

	SUBROUTINE		removeProject
	
	PURPOSE

		REMOVE A PROJECT FROM THE project, workflow, groupmember, stage AND

		stageparameter TABLES, AND REMOVE THE PROJECT FOLDER AND DATA FILES
      
=cut

	my $json 			=	$self->json();

    #### VALIDATE
    $self->logError("User session not validated") and exit unless $self->validate();

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $required_fields = ["username", "projectname"];
	my $not_defined = $self->db()->notDefined($json, $required_fields);
    $self->logError("undefined values: @$not_defined") and exit if @$not_defined;

	#### REMOVE FROM project TABLE
  my $success = $self->_removeProject($json);
  $self->logError("Can't remove project") and exit if not $success;
 	
	#### REMOVE FROM workflow
	my $table = "workflow";
	$required_fields = ["username", "projectname"];
	$success = $self->_removeFromTable($table, $json, $required_fields);
 	$self->logError("Could not delete project $json->{project} from the $table table") and exit if not defined $success;

	#### REMOVE FROM stage
	$table = "stage";
	$success = $self->_removeFromTable($table, $json, $required_fields);
 	$self->logError("Could not delete project $json->{project} from the $table table") and exit if not defined $success;

	#### REMOVE FROM stageparameter
	$table = "stageparameter";
	$success = $self->_removeFromTable($table, $json, $required_fields);
 	$self->logError("Could not delete project $json->{project} from the $table table") and exit if not defined $success;

	#### REMOVE FROM groupmember
	$table = "groupmember";
	$json->{owner} = $json->{username};
	$json->{type} = "project";
	$success = $self->_removeFromTable($table, $json,  ["owner", "name", "type"]);
 	$self->logError("Could not delete project $json->{project} from the $table table") and exit if not defined $success;

#	#### REMOVE FROM clusters
#	$table = "cluster";
#	$success = $self->_removeFromTable($table, $json, $required_fields);
# 	$self->logError("Could not delete project $json->{project} from the $table table") and exit if not defined $success;

	#### REMOVE PROJECT DIRECTORY
  my $username = $json->{'username'};
	$self->logDebug("username", $username);
	my $fileroot = $self->util()->getFileroot($username);
	$self->logDebug("fileroot", $fileroot);
	my $filepath = "$fileroot/$json->{project}";
	if ( $^O =~ /^MSWin32$/ )   {   $filepath =~ s/\//\\/g;  }
	$self->logDebug("Removing directory", $filepath);
	
	$self->logError("Cannot remove directory: $filepath") and exit if not File::Remove::rm(\1, $filepath);

	$self->logStatus("Deleted project $json->{project}");
	
}	#### removeProject


method getProjects {
=head2

    SUBROUTINE:     getProjects
    
    PURPOSE:

		RETURN AN ARRAY OF project HASHES
			
			E.G.:
			[
				{
				  'name' : 'NGS',
				  'desciption' : 'NGS analysis team',
				  'notes' : 'This project is for ...',
				},
				{
					...
			]

=cut

  #### GET PROJECTS
  my $username = $self->username();
  my $projects = $self->_getProjects($username);
    
	######## IF NO RESULTS:
	####	1. INSERT DEFAULT PROJECT INTO project TABLE
	####	2. CREATE DEFAULT PROJECT FOLDERS
	return $self->_defaultProject() if not defined $projects;

	return $projects;
}


method _getProjects ($username) {
#### GET PROJECTS FOR THIS USER    
  $self->logDebug("username", $username);
	my $query = qq{SELECT * FROM project
WHERE username='$username'
ORDER BY projectname};
	$self->logDebug("query", $query);
    
	return $self->db()->queryhasharray($query);
}

method _defaultProject {
=head2

	SUBROUTINE		_defaultProject
	
	PURPOSE

		1. INSERT DEFAULT PROJECT INTO project TABLE
		
		2. RETURN QUERY RESULT OF project TABLE
		
=cut

	my $username	=	$self->username();
	$self->logDebug("username", $username);
	
	#### SET DEFAULT PROJECT
	my $data = {
		username			=>	$username,
		projectname		=>	 "Project1"		
	};
	
	#### ADD PROJECT
	my $success = $self->_addProject($data);
	$self->logError("Could not add project $data->{name} into  project table") and return [] if not defined $success;

	return [ $data ];
}

method projectIsRunning ($username, $projectname) {	
	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);

	my $query = qq{SELECT 1 from projectname
WHERE username='$username'
AND projectname='$projectname'
AND status='running'
};
	$self->logDebug("query", $query);
  my $result =  $self->db()->query($query) || 0;
	$self->logDebug("Returning result", $result);
	
	return $result
}

1;
