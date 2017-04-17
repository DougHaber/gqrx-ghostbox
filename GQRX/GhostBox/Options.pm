package GQRX::GhostBox::Options;

use warnings;
use strict;

use Getopt::Long qw(:config no_ignore_case);


sub show_usage {
    # Show the usage help message
    # This accepts an optional $error_message string.  If defined,
    # this is printed before the help as an error message and the exit
    # code is 1.  Otherwise, the exit code will be 0.
    my ($error_message) = @_;

    if ($error_message) {
        print STDERR "ERROR: $error_message\n\n";
    }

    print <<EOF;
Usage: gqrx-ghostbox [OPTIONS]
  GENERAL:
    -h, --help                          Display this detailed help message
    --debug                             Print extra debugging output

  CONNECTION:
    -H, --host={IP_ADDRESS}             GQRX Host IP (default is 127.0.0.1)
    -P, --port={PORT}                   GQRX Port (default is 7356)
    -h, --help                          Show this help message

  RADIO SETTINGS:
    -d, --demodulator-mode={MODE}       The GQRX demodulator mode to use
                                        (default is 'WFM')
                                        Options: AM, CW, CWL, CWU, FM, LSB, USB,
                                	WFM, WFM_ST, WFM_ST_OIRT

  SCANNING SETTINGS:
    --min, --min-frequency={FREQUENCY}  Minimum frequency to scan in KHz
                                        (default is '88000', FM min)
    --max, --max-frequency={FREQUENCY}  Maximum frequency to scan in KHz
                                        (default is '108000', FM max)
    -m, --scanning-mode={MODE}          Method of scanning
                                        (default is 'bounce')
                                        Options: forward, reverse, bounce, random
    -s, --scanning-step={STEP_SIZE}     How many KHz to move when scanning
                                        (default is 150)
					This has no effect in "random" mode
    -S, --sleep={TIME}			Time to hold a frequency for each step
	                                in ms. (default is '100')


  NOISE GENERATORS: (web client only)
    --brown=[volume]                    Enable brown noise generation at the
                                        specified volume (0 to 1, default is 0.7)
    --pink=[volume]                     Enable pink noise generation at the
                                        specified volume (0 to 1, default is 0.7)
    --white=[volume]                    Enable white noise generation at the
                                        specified volume (0 to 1, default is 0.7)

  WEB SERVER:
    -n, --no-web                        Do not run a web server
    -g, --global-web                    Listen on all interfaces instead of only local
                                        (WARNING: For security, this is discouraged.)
    -w, --web-port={PORT}               Port to listen on (default is 8888)

EOF

    exit ($error_message ? 1 : 0);
}


sub setup_noise_options {
    my ($noise_options, $options) = @_;
    my $name;

    foreach $name (keys %$noise_options) {
        my $volume = $noise_options->{$name};

        if (defined($volume)) {
            $options->{"${name}_noise_volume"} = $volume;
            $options->{"${name}_noise"} = 1;
        }
    }
}


sub add_error {
    my ($errors, $key, $message) = @_;
    my $camel_key = $key;

    # Convert the key to camel case for the web clients
    $camel_key =~ s/(_([a-z]))/\U$2\E/g;

    push (@$errors, { key => $key,
                      camelKey => $camel_key,
                      message => "ERROR: $message" });
}


sub validate_option {
    # Validate an option based on rules
    # Return 1 on success, or undef
    my ($options, $errors, $rules) = @_;
#    print "validate_options.  key=$rules->{key},    value=".$options->{$rules->{key}}."\n";
    my $key = $rules->{key};
    my $value = $options->{$key};

    if ($rules->{regex} && $value !~ $rules->{regex}) {
        add_error($errors, $key, $rules->{error} || "Invalid value for $key");
    }
    elsif ($rules->{type} && $rules->{type} eq 'number' && $value !~ /^-?\d+(\.\d+)?$/) {
        add_error($errors, $key, $rules->{error} || "Field $key must be a number");
    }
    elsif ($rules->{min} && $value < $rules->{min}) {
        add_error($errors, $key, $rules->{error} || "Field $key must be greater than or equal to " .
                  ($rules->{min}));
    }
    elsif ($rules->{max} && $value > $rules->{max}) {
        add_error($errors, $key, $rules->{error} || "Field $key must be less than or equal to " .
                  ($rules->{max}));
    }
    else {
        return 1;
    }

    return undef;
}


sub validate_options {
    # Validate the options and return an arrayref list of errors
    # Errors are objects with keys: key, message
    my ($options) = @_;
    my @errors = ();
    my $has_frequency_error = 0;
    my $key;

    # Validate options using regex
    validate_option($options, \@errors, {
        key => 'gqrx_host',
        regex => '^(\d{1,3}\.){3}\d{1,3}$',
        error => "The host must be set to a valid IPv4 address" });
    validate_option($options, \@errors, {
        key => 'demodulator_mode',
        regex => '^(AM|CW|CWL|CWU|FM|LSB|USB|WFM|WFM_ST|WFM_ST_OIRT)$',
        error => "Unknown demodulator mode" });
    validate_option($options, \@errors, {
        key => 'scanning_mode',
        regex => '^(FORWARD|REVERSE|BOUNCE|RANDOM)$',
        error => "Unknown scanning mode" });


    # Validate Sleep Time
    validate_option($options, \@errors, {
        key => 'sleep_time',
        type => 'number',
        min => 1,
        max => 10000 });

    # Validate frequency options
    validate_option($options, \@errors, {
        key => 'scanning_step',
        type => 'number',
        min => 1 });

    foreach $key (qw( min_frequency max_frequency )) {
        if (! validate_option($options, \@errors, {
                 key => $key,
                 type => 'number',
                 min => 1 })) {
            $has_frequency_error = 1;
        }
    }

    if (! $has_frequency_error && $options->{min_frequency} >= $options->{max_frequency}) {
        add_error(\@errors, 'min_frequency',
                  'The minimum frequency must be less than the maximum frequency');
    }

    # Validate port options
    foreach $key (qw( gqrx_port web_port )) {
        validate_option($options, \@errors, {
            key => $key,
            type => 'number',
            min => 1,
            max => 65535 });
    }

    # Validate noise options
    foreach $key (qw( brown pink white )) {
        validate_option($options, \@errors, {
            key => "${key}_noise_volume",
            type => 'number',
            min => 0,
            max => 1 });

        validate_option($options, \@errors, {
            key => "${key}_noise",
            regex => '^(0|1)$' });
    }

    return (@errors);
}


sub setup_options {
    my ($options) = @_;

    # Convert the options to the expected value
    $options->{scanning_step} *= 1000;
    $options->{min_frequency} *= 1000;
    $options->{max_frequency} *= 1000;
    $options->{sleep_time} *= 1000;

    # If bounce is enabled, pick a starting direction
    if ($options->{scanning_mode} eq 'BOUNCE') {
        $options->{scanning_mode} = rand() > 0.5 ? 'FORWARD' : 'REVERSE';
        $options->{bounce} = 1;
    }
    else {
        $options->{bounce} = 0;
    }

    # Setup a random starting frequency within the range
    $options->{frequency} = int(rand($options->{max_frequency} - $options->{min_frequency}) +
                                $options->{min_frequency});
}


sub parse_options {
    # Read in and validate the command line options
    # Return a hashref of options
    my %options = (
        bounce => 0,                # Oscillate the scanning mode when true
        brown_noise => 0,
        brown_noise_volume => 0.7,
        debug => 0,                 # Provide extra output when enabled
        demodulator_mode => 'WFM',  # Options: AM, FM, WFM, WFM_ST, WFM_ST_OIRT, LSB, USB, CW, CWL, CWU
        global_web_server => 0,     # Listen on all interfaces
        gqrx_host => '127.0.0.1',
        gqrx_port => 7356,
        help => 0,
        max_frequency => 108000,    # Maximum frequency to use in KHz
        min_frequency => 88000,     # Minimum frequency to use in KHz
        no_web_server => 0,
        pink_noise => 0,
        pink_noise_volume => 0.7,
        scanning_mode => 'bounce',  # Options: forward, reverse, bounce, random
        scanning_step => 150,       # The size of each step in KHz for linear scanning
        sleep_time => 100,           # Number of ms to wait before changing frequency
        web_port => 8888,
        white_noise => 0,
        white_noise_volume => 0.7
        );
    my %noise_options = ( # Separate hash to read/configure noise options from the CLI
        brown => undef,
        pink => undef,
        white => undef,
        );
    my @errors;

    if (! GetOptions(
              "brown=f"              => \$noise_options{brown},
              "debug"                => \$options{debug},
              "demodulator-mode|d=s" => \$options{demodulator_mode},
              "global-web|g"         => \$options{global_web_server},
              "help|h"               => \$options{help},
              "host|H=s"             => \$options{gqrx_host},
              "max-frequency|max=f"  => \$options{max_frequency},
              "min-frequency|min=f"  => \$options{min_frequency},
              "no-web|n"             => \$options{no_web_server},
              "pink=f"               => \$noise_options{pink},
              "port|P=i"             => \$options{gqrx_port},
              "scanning-mode|m=s"    => \$options{scanning_mode},
              "scanning-step|s=f"    => \$options{scanning_step},
              "sleep-time|S=f"       => \$options{sleep_time},
              "web-port|w=i"         => \$options{web_port},
              "white=f"              => \$noise_options{white}
        )) {
        show_usage();
    }

    if ($options{help}) {
        show_usage();
    }

    # Take the noise volumes from the CLI and set the appropriate options
    setup_noise_options(\%noise_options, \%options);

    # Convert any provide modes to upper case
    $options{demodulator_mode} = uc($options{demodulator_mode});
    $options{scanning_mode} = uc($options{scanning_mode});

    # Fail on any invalid options
    @errors = validate_options(\%options);
    if ($#errors >= 0) {
        die($errors[0]->{message} . "\n");
    }

    setup_options(\%options);

    return (\%options);
}


1;
