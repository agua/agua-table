#!/usr/bin/perl -w

BEGIN {
    my $arch = $^O;
    if ( $arch eq "darwin" ) {
        my $installdir = $ENV{'installdir'} || "/a";
        unshift(@INC, "$installdir/extlib/osx/lib/perl5");
        unshift(@INC, "$installdir/extlib/osx/lib/perl5/x86_64-linux-gnu-thread-multi/");
        unshift(@INC, "$installdir/lib");
    }
    elsif ( $arch eq "linux" ) {
        my $installdir = $ENV{'installdir'} || "/a";
        unshift(@INC, "$installdir/extlib/linux/lib/perl5");
        unshift(@INC, "$installdir/extlib/linux/lib/perl5/x86_64-linux-gnu-thread-multi/");
        unshift(@INC, "$installdir/lib");
    }
    elsif ( $arch eq "MSWin32" ) {
        my $installdir = $ENV{'installdir'} || "/a";
        unshift(@INC, "$installdir/extlib/win/lib/perl5");
        unshift(@INC, "$installdir/extlib/win/lib/perl5/MSWin32-x86-multi-thread-64int/");
        unshift(@INC, "$installdir/lib");
    }
}

=head2

    NAME		loadSamples
    
    PURPOSE
	
		Load a list of sample ids, filenames and file sizes

    INPUT
	
		1. USERNAME
		2. PROJECT NAME
		3. WORKFLOW NAME
		4. WORKFLOW NUMBER
		5. LOCATION OF .TSV FILE

    OUTPUT
	
		1. POPULATED ROWS IN queuesample DATABASE TABLE

    USAGE
	
		./loadSamples.pl <--username String> <--project String> <--table String> <--sqlfile String> <--tsvfile String> [-h] 

    --username	  :   Name of user (e.g., admin)
    --project	  :   Name of project (e.g., AlignBams)
    --table       :   Name of table (e.g., loadSamples)
    --sqlfile	  :   Location of *.sql file
    --tsvfile	  :   Location of *.tsv file
    --help        :   print this help message

	< option > denotes REQUIRED argument
	[ option ] denotes OPTIONAL argument

    EXAMPLE

/a/bin/sample/loadSamples.pl \
--username admin \
--project QC \
--table samples21 \
--sqlfile /mnt/repos/private/syoung/dnaseq/data/sql/samples21.sql \
--tsvfile /mnt/repos/private/syoung/dnaseq/data/tsv/samples21.tsv \
--log 4

=cut

#### EXTERNAL MODULES
use Data::Dumper;
use Getopt::Long;
use FindBin qw($Bin);

#### INTERNAL MODULES
use lib "..";
use Engine::Workflow;
use Conf::Yaml;

#### SET LOG
my ($script)	=	$0	=~	/([^\.^\/]+)\.pl/;
my $logfile 	= "/tmp/$script.$$.log";

#### GET OPTIONS
my $log 		= 	2;
my $printlog 	= 	5;

my $username;
my $project;
my $table;
my $sqlfile;	
my $tsvfile;	
my $help;
GetOptions (
	'username=s' 	=> \$username,
	'project=s' 	=> \$project,
	'table=s' 		=> \$table,
	'sqlfile=s' 	=> \$sqlfile,
	'tsvfile=s' 	=> \$tsvfile,

	'log=i' 		=> \$log,
	'printlog=i' 	=> \$printlog,
	'help' => \$help) or die "No options specified. Try '--help'\n";
if ( defined $help )	{	usage();	}

#### CHECK INPUTS
die "username not defined (option --username)\n" if not defined $username;
die "project not defined (option --project)\n" if not defined $project;
die "table not defined (option --table)\n" if not defined $table;
die "sqlfile not defined (option --sqlfile)\n" if not defined $sqlfile; 
die "tsvfile not defined (option --tsvfile)\n" if not defined $tsvfile; 

#### GET CONF
my $configfile = "$Bin/../../conf/config.yml";
my $conf = Conf::Yaml->new({
	inputfile 	=> $configfile,
	logfile		=>	$logfile,
	log			=>	2,
	printlog	=>	5
});

my $object = Engine::Workflow->new({
	conf		=>	$conf,
	configfile	=>	$configfile,
	logfile		=>	$logfile,
	log			=>	$log,
	printlog	=>	$printlog
});

$object->loadSamples($username, $project, $table, $sqlfile, $tsvfile);

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#									SUBROUTINES
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


sub usage
{
    print `perldoc $0`;
	exit;
}
