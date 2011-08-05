package Moo::Object;

use strictures 1;

our %NO_BUILD;
our $BUILD_MAKER;

sub new {
  my $class = shift;
  $NO_BUILD{$class} and
    return bless({ ref($_[0]) eq 'HASH' ? %{$_[0]} : @_ }, $class);
  $NO_BUILD{$class} = !$class->can('BUILD') unless exists $NO_BUILD{$class};
  $NO_BUILD{$class}
    ? bless({ ref($_[0]) eq 'HASH' ? %{$_[0]} : @_ }, $class)
    : do {
        my $proto = ref($_[0]) eq 'HASH' ? $_[0] : { @_ };
        bless({ %$proto }, $class)->BUILDALL($proto);
      };
}

# Inlined into Method::Generate::Constructor::_generate_args() - keep in sync
sub BUILDARGS {
    my $class = shift;
    if ( scalar @_ == 1 ) {
        unless ( defined $_[0] && ref $_[0] eq 'HASH' ) {
            die "Single parameters to new() must be a HASH ref"
                ." data => ". $_[0] ."\n";
        }
        return { %{ $_[0] } };
    }
    elsif ( @_ % 2 ) {
        die "The new() method for $class expects a hash reference or a key/value list."
                . " You passed an odd number of arguments\n";
    }
    else {
        return {@_};
    }
}

sub BUILDALL {
  my $self = shift;
  $self->${\(($BUILD_MAKER ||= do {
    require Method::Generate::BuildAll;
    Method::Generate::BuildAll->new
  })->generate_method(ref($self)))}(@_);
}

sub DESTROY {
    my $self = shift;

    return unless $self->can('DEMOLISH'); # short circuit

    require Moo::_Utils;

    my $e = do {
        local $?;
        local $@;
        eval {
            # DEMOLISHALL

            # We cannot count on being able to retrieve a previously made
            # metaclass, _or_ being able to make a new one during global
            # destruction. However, we should still be able to use mro at
            # that time (at least tests suggest so ;)

            foreach my $class (@{ Moo::_Utils::_get_linear_isa(ref $self) }) {
                my $demolish = $class->can('DEMOLISH') || next;

                $self->$demolish($Moo::_Utils::_in_global_destruction);
            }
        };
        $@;
    };

    no warnings 'misc';
    die $e if $e; # rethrow
}



sub does {
  require Role::Tiny;
  { no warnings 'redefine'; *does = \&Role::Tiny::does_role }
  goto &Role::Tiny::does_role;
}

1;
