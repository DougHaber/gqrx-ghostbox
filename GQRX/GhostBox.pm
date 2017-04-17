# This module has been inlined to keep packaging simple.  If the application
# grows, it should be broken apart.
package GQRX::GhostBox;

use Time::HiRes qw(usleep);
use Getopt::Long qw(:config no_ignore_case);

use warnings;
use strict;


################################################################################
# Interface
################################################################################

sub new {
    my ($class, $options) = @_;
    my $self = {
        remote         => undef,     # GQRX::Remote object
        options        => $options,  # Runtime options (from GQRX::GhostBox::Options)
        signal_history => [],        # Track recent signal strength history
        signal_counter => 0          # Unique id for recorded signals (increments for each)
    };

    if (! $options) {
        die "ERROR: GQRX::GhostBox can not be initialized without an \$options\n";
    }

    bless ($self, $class);

    return ($self);
}

sub start {
    my ($self) = @_;

    $self->connect_to_gqrx();

    # Set the default demodulator mode
    $self->{remote}->set_demodulator_mode($self->{options}->{demodulator_mode});
}


sub record_signal_strength {
    my ($self) = @_;
    my $signal_strength = $self->{remote}->get_signal_strength();

    if ($signal_strength) {
        unshift(@{ $self->{signal_history} }, {
            frequency => $self->{options}->{frequency} / 1000,
            strength => $signal_strength,
            id => $self->{signal_counter}++
             });
        splice(@{ $self->{signal_history} }, 10);
    }
}


sub update {
    my ($self) = @_;

    $self->next_frequency();
    $self->record_signal_strength();

    if ($self->{options}->{debug}) {
        print "Setting frequency: $self->{options}->{frequency}\n";
    }
}



################################################################################
# Networking
################################################################################

sub connect_to_gqrx {
    my ($self) = @_;

    $self->{remote} = GQRX::Remote->new();

    if (! $self->{remote}->connect(host => $self->{options}->{gqrx_host},
                                   port => $self->{options}->{gqrx_port})) {
        die "ERROR: Failed to establish connection to Gqrx " .
            "at $self->{options}->{gqrx_host}:$self->{options}->{gqrx_port}\n";
    }
}


################################################################################
# Scanning
################################################################################

sub next_frequency {
    my ($self) = @_;
    my $options = $self->{options};

    if ($options->{scanning_mode} eq 'RANDOM') {
        $options->{frequency} = int(rand($options->{max_frequency} - $options->{min_frequency}) +
                                    $options->{min_frequency});
    }
    elsif ($options->{scanning_mode} eq 'REVERSE') {
        $options->{frequency} = $options->{frequency} - $options->{scanning_step};

        if ($options->{frequency} < $options->{min_frequency}) {
            if ($options->{bounce}) {
                $options->{scanning_mode} = 'FORWARD';
                $self->next_frequency();
            }
            else {
                $options->{frequency} = $options->{frequency} + $options->{max_frequency} -
                    $options->{min_frequency};
            }
        }
    }
    else { # Default is forward
        $options->{frequency} = $options->{frequency} + $options->{scanning_step};

        if ($options->{frequency} > $options->{max_frequency}) {
            if ($options->{bounce}) {
                $options->{scanning_mode} = 'REVERSE';
                $self->next_frequency();
            }
            else {
                $options->{frequency} = $options->{frequency} - $options->{max_frequency} +
                    $options->{min_frequency};
            }
        }
    }

    if (! $self->{remote}->set_frequency($options->{frequency})) {
        die "ERROR: set_frequency() failed: " . $self->{remote}->error() . "\n";
    }
}


1;
