package Dancer2::Plugin2;
# ABSTRACT: base class for Dancer2 plugins

=head1 SYNOPSIS

The plugin itself:


    package Dancer2::Plugin::Polite;

    use strict;
    use warnings;

    use Moo;
    extends 'Dancer2::Plugin2';

    has smiley => (
        is => 'ro',
        default => sub {
            $_[0]->config->{smiley} || ':-)'
        }
    );

    sub keywords { 'add_smileys' }

    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_hook( Dancer2::Core::Hook->new(
            name => 'after',
            code => sub { $_[0]->content( $_[0]->content . " ... please?" ) }
        ));

        $plugin->app->add_route(
            method => 'get',
            regexp => '/goodbye',
            code   => sub { 'farewell!' },
        );

    }

    sub add_smileys {
        my( $plugin, $text ) = @_;

        $text =~ s/ (?<= \. ) / $plugin->smiley /xeg;

        return $text;
    }

    1;

then to load into the app:


    package MyApp;

    use strict;
    use warnings;

    use Dancer2;

    BEGIN { # would usually be in config.yml
        set plugins => {
            Polite => {
                smiley => '8-D',
            },
        };
    }

    use Dancer2::Plugin::Polite ':app';

    get '/' => sub {
        add_smileys( 'make me a sandwich.' );
    };

    1;


=head1 DESCRIPTION

This is an alternate plugin basis for Dancer2.

=head2 Writing the plugin

=head3 Inheriting from L<Dancer2::Plugin2>

The plugin must inherit from L<Dancer2::Plugin2>. The base clase provides the plugin with 
two attributes: C<app>, which is populated with the Dancer2 app object for which
the plugin is being initialized for, and C<config> which holds the plugin 
section of the application configuration.

=head3 Modifying the app at building time

If the plugin needs to tinker with the application -- add routes or hooks, for example --
it can do so within its C<BUILD()> function.

    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_route( ... );
    }

=head3 Adding keywords

Keywords that the plugin wishes to export to the Dancer2 app must be defined in a 
C<keywords> function:

    sub keywords { qw/ add_smileys add_sad_kitten  / }

Then each of the keyword is written as a function which first argument will
be the plugin object itself.

    sub add_smileys {
        my( $plugin, $text ) = @_;

        return join ' ', $text, $plugin->smiley;
    }

    # and then in the app

    get '/' => sub {
        add_smileys( "Hi there!" );
    };

=head2 Using the plugin within the app

A plugin is loaded via

    use Dancer2::Plugin::Polite ':app';

The C<:app> must be there for the plugin to be tied to the app, and for the 
keywords to be imported to the namespace.

=head2 Plugins using plugins

This is a (relatively) simple way for a plugin to use another plugin: 


    package Dancer2::Plugin::SourPuss;

    has polite => (
        is => 'ro',
        lazy => 1,
        default => sub {
            # if the app already has the 'Polite' plugin loaded, it'll return
            # it. If not, it'll load it in the app, and then return it.
            scalar $_[0]->app->with_plugins( 'Polite' )
        },
        handles => { 'smiley' => 'smiley' },
    );

    sub keywords { qw/ killjoy / }

    sub killjoy {
        my( $plugin, $text ) = @_;

        my $smiley = $plugin->smiley;

        $text =~ s/ $smiley />:-(/xg;

        $text;
    }


=cut

use strict;
use warnings;

use Moo;

extends 'Exporter::Tiny';

sub _exporter_expand_tag {
    my( $class, $name, $args, $global ) = @_;

    return unless $name eq 'app';

    my $caller = $global->{into};

    die "plugin called with ':app' in a class without app()\n"
        unless $caller->can('app');

    ( my $short = $class ) =~ s/Dancer2::Plugin:://;

    my $app = eval "${caller}::app()";

    my $plugin = $app->with_plugins( $short );
    $global->{plugin} = $plugin;

    return unless $class->can('keywords');

    map { [ $_ =>  {plugin => $plugin}  ] } $class->keywords;
}

sub _exporter_expand_sub {
    my( $plugin, $name, $args, $global ) = @_;

    return $name => sub(@) { $args->{plugin}->$name(@_) };
}


has app => (
#    isa => Object['Dancer2::Core::App'],
    is => 'ro',
    required => 1,
);

has config => (
    is => 'ro',
    lazy => 1,
    default => sub { 
        my $self = shift;
        my $config = $self->app->config;
        my $package = ref $self; # TODO
        $package =~ s/Dancer2::Plugin:://;
        $config->{plugins}{$package}
    },
);

1;