use MooseX::Declare;

class Test::Table::Workflow with (Table::Workflow, Util::Logger, Table::Main, Table::Common, Test::Common) {
use Data::Dumper;
use Test::More;
#use Test::DatabaseRow;
use DBase::Factory;

# INTS
has 'workflowpid'	=> ( isa => 'Int|Undef', is => 'rw', required => 0 );
has 'workflownumber'=>  ( isa => 'Str', is => 'rw' );
has 'start'     	=>  ( isa => 'Int', is => 'rw' );
has 'submit'  		=>  ( isa => 'Int', is => 'rw' );

# STRINGS
has 'dumpfile'		=>  ( isa => 'Str|Undef', is => 'rw' );
has 'database'		=>  ( isa => 'Str|Undef', is => 'rw' );
has 'fileroot'	=> ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'qstat'		=> ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'queue'			=>  ( isa => 'Str|Undef', is => 'rw', default => 'default' );
has 'cluster'		=>  ( isa => 'Str|Undef', is => 'rw' );
has 'username'  	=>  ( isa => 'Str', is => 'rw' );
has 'workflow'  	=>  ( isa => 'Str', is => 'rw' );
has 'project'   	=>  ( isa => 'Str', is => 'rw' );

# OBJECTS
has 'json'		=> ( isa => 'HashRef', is => 'rw', required => 0 );
has 'db'	=> ( isa => 'DBase::MySQL', is => 'rw', required => 0 );
has 'stages'		=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'stageobjects'	=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'monitor'		=> 	( isa => 'Maybe|Undef', is => 'rw', required => 0 );

has 'conf' 	=> (
	is =>	'rw',
	'isa' => 'Conf::Yaml',
	default	=>	sub { Conf::Yaml->new( backup	=>	1 );	}
);


####///}}}
method BUILD ($hash) {
	$self->initialise();
}

method initialise () {
    $self->logDebug("()");
	my $dumpfile 	= $self->dumpfile();
	$self->reloadTestDatabase( { dumpfile => $dumpfile } );	
    $Test::DatabaseRow::dbh = $self->db()->dbh();	
}

method testAddWorkflow () {
	diag("Test addWorkflow");

	my $username = $self->conf()->getKey("database:TESTUSER");
	my $table 	= "workflow";

	my $data = {
		"username"	=>	$username,
		"project"	=>	"Project1",
		"name"		=>	"Workflow1",
		"number"	=>	"1",
		"description"=>	"Workflow description",
		"notes"	    =>	"Notes",
	};
	my $project 	= $data->{project};
	my $name 		= $data->{name};
	my $number 		= $data->{number};

	#### VERIFY ENTRY IS NOT PRESENT
	my $where = "WHERE username='$username' AND project='$project' AND name='$name' AND number='$number'";
	my $method=	"_addWorkflow";
    my $label =     "Entry does not exist in '$table' BEFORE $method";
    $self->verifyNoRows($table, $where, $label);
	
	$where = "WHERE username='$username' AND project='$project' AND name='$name'";
	my $rowcount_initial = $self->rowCount($table, $where);
        
    $self->_addWorkflow($data);

    my $rowcount_afteradd = $self->rowCount($table, $where);

    ok($rowcount_initial + 1 == $rowcount_afteradd, "One row added. Current rows: $rowcount_afteradd");

	#### TEST INSERTED FIELD VALUES
	my $rows = $self->verifyRows($table, $where, "Workflow exists in 'workflow' table AFTER _addWorkflow");
	
	ok(scalar(@$rows) == 1, "unique row matches added stage");
    my $inserted = $$rows[0];
	$self->logDebug("inserted", $inserted);
	
	ok($inserted->{name}	eq	$data->{name}, "name field value matches");
	ok($inserted->{number}	eq	$data->{number}, "number field value matches");
	ok($inserted->{project}	eq	$data->{project}, "project field value matches");
	ok($inserted->{username}	eq	$data->{username}, "username field value matches");
	ok($inserted->{description}	eq	$data->{description}, "description field value matches");
	ok($inserted->{notes}	eq	$data->{notes}, "notes field value matches");

    $self->_removeWorkflow($data);

    my $rowcount_afterremove = $self->rowCount($table, $where);

    ok($rowcount_afterremove + 1 == $rowcount_afteradd, "One row removed. Current rows: $rowcount_afterremove");

	$self->verifyNoRows($table, $where, "Workflow doesn't exist in 'workfoow' table AFTER _removeWorkflow");
}


}   #### Test::Table::Workflow