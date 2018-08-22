#!/usr/bin/perl -w

use Test::More	tests => 18;

use FindBin qw($Bin);
use lib "$Bin/../../../../lib";
BEGIN
{
    my $installdir = $ENV{'installdir'} || "/a";
    unshift(@INC, "$installdir/t/unit/lib");
    unshift(@INC, "$installdir/t/common/lib");
    unshift(@INC, "$installdir/extlib/lib/perl5");
    unshift(@INC, "$installdir/extlib/lib/perl5/x86_64-linux-gnu-thread-multi/");
    unshift(@INC, "$installdir/lib");
    unshift(@INC, "$installdir/lib/external/lib/perl5");
}

#### CREATE OUTPUTS DIR
my $outputsdir = "$Bin/outputs";
`mkdir -p $outputsdir` if not -d $outputsdir;


BEGIN {
    use_ok('Conf::Yaml');
    use_ok('Test::Table::Workflow');
}
require_ok('Conf::Yaml');
require_ok('Test::Table::Workflow');

#### SET CONF FILE
my $installdir  =   $ENV{'installdir'} || "/a";
my $configfile  =   "$installdir/conf/config.yml";

#### SET $Bin
$Bin =~ s/^.+t\/bin/$installdir\/t\/unit\/bin/;

my $logfile = "$Bin/outputs/testuser.workflow.log";
my $log     =   2;
my $printlog    =   5;

my $conf = Conf::Yaml->new(
    inputfile	=>	$configfile,
    backup	    =>	1,
    separator	=>	"\t",
    spacer	    =>	"\\s\+",
    logfile     =>  $logfile,
	log     =>  2,
	printlog    =>  2    
);
isa_ok($conf, "Conf::Yaml", "conf");

#### SET DUMPFILE
my $dumpfile    =   "$Bin/../../../../dump/create.dump";

my $username = $conf->getKey("database:TESTUSER");

my $object = new Test::Table::Workflow(
    conf        =>  $conf,
    dumpfile    =>  $dumpfile,
    logfile     =>  $logfile,
	log			=>	$log,
	printlog    =>  $printlog
#    ,
#	username	=>	$username
);
isa_ok($object, "Test::Table::Workflow", "workflow");

#### ADD WORKFLOW
$object->testAddWorkflow();


__END__

echo '{"project":"Project1","name":"Workflow3","number":"3","newnumber":2,"mode":"moveWorkflow","username":"syoung","sessionId":"1234567890.1234.123"}' | /var/www/cgi-bin/agua/0.6/workflow.cgi

echo '{"project":"Project1","name":"Workflow3","number":"2","newnumber":3,"mode":"moveWorkflow","username":"syoung","sessionId":"1234567890.1234.123"}' | /var/www/cgi-bin/agua/0.6/workflow.cgi

echo '{"project":"Project1","name":"Workflow3","number":"3","newnumber":2,"mode":"moveWorkflow","username":"syoung","sessionId":"1234567890.1234.123"}' | /var/www/cgi-bin/agua/0.6/workflow.cgi
Content-type: text/html

echo '{"project":"Project1","name":"Workflow3","number":"2","newnumber":5,"mode":"moveWorkflow","username":"syoung","sessionId":"1234567890.1234.123"}' | /var/www/cgi-bin/agua/0.6/workflow.cgi

echo '{"project":"Project1","name":"Workflow3","number":"5","newnumber":1,"mode":"moveWorkflow","username":"syoung","sessionId":"1234567890.1234.123"}' | /var/www/cgi-bin/agua/0.6/workflow.cgi

echo '{"project":"Project1","name":"Workflow3","number":"1","newnumber":3,"mode":"moveWorkflow","username":"syoung","sessionId":"1234567890.1234.123"}' | /var/www/cgi-bin/agua/0.6/workflow.cgi

