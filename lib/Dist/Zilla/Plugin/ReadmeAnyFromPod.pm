package Dist::Zilla::Plugin::ReadmeAnyFromPod;

use Moose;
use Moose::Autobox;
use MooseX::Has::Sugar;
use Moose::Util::TypeConstraints qw(enum);
use IO::Handle;
use Encode qw( encode );

with 'Dist::Zilla::Role::InstallTool';

my $types = {
    text => {
        filename => 'README',
        parser => sub {
            my $mmcontent = $_[0];

            require Pod::Text;
            my $parser = Pod::Text->new();
            $parser->output_string( \my $input_content );
            $parser->parse_string_document( $mmcontent );

            my $content;
            if( defined $parser->{encoding} ){
                $content = encode( $parser->{encoding} , $input_content );
            } else {
                $content = $input_content;
            }
            return $content;
        },
    },
    markdown => {
        filename => 'README.mkdn',
        parser => sub {
            my $mmcontent = $_[0];

            require Pod::Markdown;
            my $parser = Pod::Markdown->new();

            require IO::Scalar;
            my $input_handle = IO::Scalar->new(\$mmcontent);

            $parser->parse_from_filehandle($input_handle);
            my $content = $parser->as_markdown();
            return $content;
        },
    },
    pod => {
        filename => 'README.pod',
        parser => sub {
            my $mmcontent = $_[0];

            require Pod::Select;
            require IO::Scalar;
            my $input_handle = IO::Scalar->new(\$mmcontent);
            my $content = '';
            my $output_handle = IO::Scalar->new(\$content);

            my $parser = Pod::Select->new();
            $parser->parse_from_filehandle($input_handle, $output_handle);

            return $content;
        },
    },
    html => {
        filename => 'README.html',
        parser => sub {
            my $mmcontent = $_[0];

            require Pod::Simple::HTML;
            my $parser = Pod::Simple::HTML->new;
            my $content;
            $parser->output_string( \$content );
            $parser->parse_string_document($mmcontent);
            return $content;
        }
    }
};

=attr type

The file format for the readme. Supported types are "text", "markdown", "pod", and "html".

=cut

has type => (
    ro, lazy,
    isa        => enum([keys %$types]),
    default    => sub { 'text' },
);

=attr filename

The file name of the README file to produce. The default depends on the selected format.

=cut

has filename => (
    ro, lazy,
    isa => 'Str',
    default => sub { $types->{$_[0]->type}->{filename}; }
);

=attr location

Where to put the generated README file. Choices are:

=over 4

=item build

This puts the README in the directory where the dist is currently
being built, where it will be incorporated into the dist.

=item root

This puts the README in the root directory (the same directory that
contains F<dist.ini>). The README will not be incorporated into the
built dist.

=back

=cut

has location => (
    ro, lazy,
    isa => enum([qw(build root)]),
    default => sub { 'build' }
);

sub get_readme_content {
    my ($self) = shift;
    my $mmcontent = $self->zilla->main_module->content;
    my $parser = $types->{$self->type}->{parser};
    my $readme_content = $parser->($mmcontent);
}

sub setup_installer {
    my ($self, $arg) = @_;

    require Dist::Zilla::File::InMemory;

    my $content = $self->get_readme_content();

    my $filename = $self->filename;
    my $file = $self->zilla->files->grep( sub { $_->name eq $filename } )->head;

    if ( $self->location eq 'build' ) {
        if ( $file ) {
            $file->content( $content );
            $self->zilla->log("Override $filename in build from [ReadmeAnyFromPod]");
        } else {
            $file = Dist::Zilla::File::InMemory->new({
                content => $content,
                name    => $filename,
            });
            $self->add_file($file);
        }
    }
    elsif ( $self->location eq 'root' ) {
        require File::Slurp;
        my $file = $self->zilla->root->file($filename);
        if (-e $file) {
            $self->zilla->log("Override $filename in root from [ReadmeAnyFromPod]");
        }
        File::Slurp::write_file("$file", $content);
    }
    else {
        die "Unknown location specified";
    }

    return;
}

__PACKAGE__->meta->make_immutable;
# ABSTRACT: Automatically convert POD to a README for Dist::Zilla

=head1 NAME

Dist::Zilla::Plugin::ReadmeAnyFromPod - Automatically convert POD to a README for Dist::Zilla

=head1 SYNOPSIS

    # dist.ini
    [ReadmeAnyFromPod]

=head1 DESCRIPTION

Generates a plain-text README for your L<Dist::Zilla> powered dist
from its C<main_module> with L<Pod::Text>.

=head1 AUTHORS

Fayland Lam <fayland@gmail.com> and E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Fayland Lam <fayland@gmail.com> and E<AElig>var
ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
