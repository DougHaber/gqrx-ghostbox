package GQRX::GhostBox::Server;

use FindBin;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Request;
use JSON;
use IO::Select;
use Scalar::Util qw(looks_like_number);
use URI::Escape;

use GQRX::GhostBox::Options;

use warnings;
use strict;

sub new {
    my ($class, $ghostbox) = @_;
    my $self = {
        ghostbox => $ghostbox,
        options => $ghostbox->{options},
        daemon => undef,
        select => IO::Select->new(),
        basedir => "$FindBin::Bin/web_files/"
    };

    bless ($self, $class);

    return ($self);
}

################################################################################
# Options
################################################################################

sub set_options {
    my ($self, $client_options) = @_;
    my $key;

    if ($self->{options}->{demodulator_mode} ne $client_options->{demodulator_mode}) {
        $self->{ghostbox}->{remote}->set_demodulator_mode($client_options->{demodulator_mode});
    }


    foreach $key (keys %$client_options) {
        $self->{options}->{$key} = $client_options->{$key}
    }

    # Scale and set legal modes and frequencies for the new options
    GQRX::GhostBox::Options::setup_options($self->{options});
}


sub get_clean_options {
    # Create an options hash for sending
    # Scale fields and only included the needed ones
    my ($self) = @_;
    my $options = $self->{options};

    return ({
        bounce => $options->{bounce},
        brownNoise => $options->{brown_noise},
        brownNoiseVolume => $options->{brown_noise_volume},
        demodulatorMode => $options->{demodulator_mode},
        gqrxHost => $options->{gqrx_host},
        gqrxPort => $options->{gqrx_port},
        maxFrequency  => int($options->{max_frequency} / 1000),
        minFrequency => int($options->{min_frequency} / 1000),
        pinkNoise => $options->{pink_noise},
        pinkNoiseVolume => $options->{pink_noise_volume},
        scanningMode => $options->{scanning_mode},
        scanningStep => int($options->{scanning_step} / 1000),
        sleepTime => int($options->{sleep_time} / 1000),
        webPort => $options->{web_port},
        whiteNoise => $options->{white_noise},
        whiteNoiseVolume => $options->{white_noise_volume},
            });
}

sub convert_option_names {
    # Convert options hashref from camel case to underscore style
    my ($self, $options) = @_;
    my @keys = keys (%$options);
    my $key;

    foreach $key (@keys) {
        my $x;
        my $converted_key = $key;

        # Convert all uppercase characters to lower case with an underscore
        $converted_key =~ s/([A-Z])/\L_$1\E/g;

        if ($key ne $converted_key) {
            $options->{$converted_key} = $options->{$key};
            delete ($options->{$key});
        }
    }
}


################################################################################
# Routes
################################################################################

sub route__get_status {
    my ($self, $connection, $request) = @_;

    $self->send_response($connection, 200, encode_json({
        currentFrequency => int($self->{options}->{frequency} / 1000),
        signalStrengthHistory => $self->{ghostbox}->{signal_history}
                                                       }));
}


sub route__get_options {
    my ($self, $connection, $request) = @_;

    $self->send_response($connection, 200, encode_json($self->get_clean_options()));
}


sub route__post_options {
    my ($self, $connection, $request) = @_;
    my $client_options;
    my $response;
    my @errors;

    eval {
        $client_options = decode_json($request->content());
    };

    if ($@) {
        print "400: POST /options: invalid JSON: $@\n";
        $connection->send_error(400);
        return;
    }

    $self->convert_option_names($client_options);
    @errors = GQRX::GhostBox::Options::validate_options($client_options);

    if ($#errors >= 0) {
        $response = HTTP::Response->new(400,
                                        undef, [
                                            'Content-Type' => 'application/json',
                                            'Cache-Control' => 'no-cache'
                                        ],
                                        encode_json(\@errors));

        print "400: POST /options: invalid options\n";
    }
    else { # On sucess, update the options
        print "200: POST /options: OK!\n";
        $self->set_options($client_options);
        $response = HTTP::Response->new(200,
                                        undef, [
                                            'Content-Type' => 'application/json',
                                            'Cache-Control' => 'no-cache'
                                        ],
                                        'OK');
    }

    $connection->send_response($response);
}


sub handle_request {
    my ($self, $connection, $request) = @_;
    my $path = uri_unescape($request->uri()->path());

    if ($request->method() eq 'GET') {
        if ($path =~ /\.\.\//) {
            print "Parent directories forbidden: $path\n";
            print "404: GET $path\n";
            $connection->send_error(404);
        }
        elsif ($path eq '/options') {
            $self->route__get_options($connection, $request);
        }
        elsif ($path eq '/status') {
            $self->route__get_status($connection, $request);
        }
        elsif (-f "$self->{basedir}${path}") {
            print "200: GET $path\n";
            $connection->send_file_response("$self->{basedir}${path}");
        }
        elsif (-d "$self->{basedir}${path}" && -f "$self->{basedir}${path}/index.html") {
            print "200: GET $path\n";
            $connection->send_file_response("$self->{basedir}${path}/index.html");
        }
        else {
            print "404: GET $path\n";
            $connection->send_error(404);
        }
    }
    elsif ($request->method() eq 'POST') {
        if ($path eq '/options') {
            $self->route__post_options($connection, $request);
        }
    }
    else {
        print "400: " . $request->method() . " " . $path . "\n";
        $connection->send_error(400);
    }
}


################################################################################
# Networking
################################################################################

sub send_response {
    my ($self, $connection, $status_code, $message) = @_;
    my $response = HTTP::Response->new($status_code,
                                       undef, [
                                           'Content-Type' => 'application/json',
                                           'Cache-Control' => 'no-cache'
                                       ],
                                       $message);

    $connection->send_response($response);
}


sub listen {
    my ($self) = @_;
    my $port = $self->{options}->{port} || 8888;
    my $addr = $self->{options}->{global_web_server} ? undef : "localhost";
    my $daemon;

    $SIG{PIPE} = 'IGNORE'; # Ignore PIPE signals from closed connections

    if (! ($daemon = HTTP::Daemon->new(LocalPort => $port, LocalAddr => $addr,
                                       Reuse => 1, Blocking => 0))) {

        print STDERR sprintf("ERROR: Failed to start daemon on %s:%d.\n", $addr || '*', $port);
        exit (1);
    }

    $self->{daemon} = $daemon;

    printf("Web server listening on %s:%d.\n", $addr || '*', $port);
}


sub check_sockets {
    my ($self) = @_;
    my $connection;

    # Add any new connections to our connection list
    while ($connection = $self->{daemon}->accept()) {
        $self->{select}->add($connection);
    }

    # Handle any connections ready to read
    foreach $connection ($self->{select}->can_read(0)) {
        my $request = $connection->get_request();

        if ($request) {
            $self->handle_request($connection, $request);
        }

        $connection->close();
        $self->{select}->remove($connection);
    }
}


1;
