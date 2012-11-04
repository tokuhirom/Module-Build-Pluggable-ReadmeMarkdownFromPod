use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'File::Temp';

{
    package Test::Module::Build::Pluggable;
    use File::Temp qw/tempdir/;
    use Cwd;
    use Test::SharedFork;
    use File::Basename;
    use File::Path;

    sub new {
        my $class = shift;
        my %args = @_==1 ? %{$_[0]} : @_;
        my $self = bless {
            %args
        }, $class;
        $self->{origcwd} = Cwd::getcwd();
        $self->{dir} = tempdir(CLEANUP => 1);
        chdir $self->{dir};
        return $self;
    }

    sub DESTROY {
        my $self = shift;
        chdir($self->{origcwd});
    }

    sub write_file {
        my ($self, $fname, $content) = @_;

        if (my $dir = dirname($fname)) {
            mkpath($dir);
        }

        open my $fh, '>', $fname or die "Cannot open $fname: $!";
        print $fh $content;
        close $fh;
    }

    sub read_file {
        my ($self, $fname) = @_;
        open my $fh, '<', $fname or die "Cannot open $fname: $!";
        local $/;
        scalar(<$fh>);
    }

    sub run_build_script {
        my $self = shift;

        my $pid = fork();
        die "fork failed: $!" unless defined $pid;
        if ($pid) { # parent
            waitpid $pid, 0;
        } else { # child
            do 'Build';
            ::ok(!$@) or ::diag $@;
            exit 0;
        }
    }

    sub run_build_pl {
        my $self = shift;

        my $pid = fork();
        die "fork failed: $!" unless defined $pid;
        if ($pid) { # parent
            waitpid $pid, 0;
        } else { # child
            do 'Build.PL';
            ::ok(-f 'Build', 'Created Build file') or ::diag $@;
            exit 0;
        }
    }
}

use File::Spec;
use lib File::Spec->rel2abs('lib');
my $test = Test::Module::Build::Pluggable->new();
$test->write_file('lib/Eg.pm', <<'...');
package Eg;
__END__

=head1 SYNOPSIS

    This is a document
...
$test->write_file('Build.PL', <<'...');
use strict;
use Module::Build::Pluggable (
    'ReadmeMarkdownFromPod'
);

my $builder = Module::Build::Pluggable->new(
    dist_name => 'Eg',
    dist_version => 0.01,
    dist_abstract => 'test',
    dynamic_config => 0,
    module_name => 'Eg',
    requires => {},
    provides => {},
    author => 1,
    dist_author => 'test',
);
$builder->create_build_script();
...

$test->run_build_pl();
$test->run_build_script();

ok(-f 'README.mkdn');
like($test->read_file('README.mkdn'), qr/This is a document/);

undef $test;

done_testing;

