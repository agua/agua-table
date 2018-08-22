# package Table::Main;
# use Moose::Role;
# use Moose::Util::TypeConstraints;

# with 'Table::App';
# with 'Table::Common';
# with 'Table::Parameter';
# with 'Table::Project';
# with 'Table::Sample';
# with 'Table::Stage';
# with 'Table::Workflow';


# 1;

use MooseX::Declare;

=head2

	PACKAGE		Table::Main
	
	PURPOSE
	
		DATABASE MANIPULATION METHODS FOR WORKFLOW OBJECTS

=cut

class Table::Main with (Util::Logger,
	Table::App,
	Table::Common,
	Table::Parameter,
	Table::Project,
	Table::Sample,
	Table::Stage,
	Table::Workflow) {

#### USE LIB FOR INHERITANCE
use FindBin qw($Bin);
use lib "$Bin/../../";
use Term::ReadKey;
use DBase::Factory;

use Data::Dumper;

has 'database'	=> ( isa => 'Str|Undef', is => 'rw' );
has 'db'      =>  ( 
  is      => 'rw', 
  isa     => 'Any', 
  lazy    =>  1,  
  builder =>  "setDbh" 
);

has 'conf'      => ( 
  is => 'rw', 
  isa => 'Conf::Yaml', 
  lazy => 1, 
  builder => "setConf" 
);

has 'util'    =>  (
  is      =>  'rw',
  isa     =>  'Util::Main',
  lazy    =>  1,
  builder =>  "setUtil"
);

method setUtil () {
  my $util = Util::Main->new({
    conf      =>  $self->conf(),
    log       =>  $self->log(),
    printlog  =>  $self->printlog()
  });

  $self->util($util); 
}

method BUILD ($args) {
  $self->initialise($args);
}

method initialise ($args) {
  # $self->logDebug("args", $args);
  $self->setDbh($args);
}


}

