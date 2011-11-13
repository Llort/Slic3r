package Slic3r::Fill::PlanePath;
use Moo;

extends 'Slic3r::Fill::Base';

use Slic3r::Geometry qw(bounding_box);
use XXX;

sub multiplier () { 1 }

sub get_n {
    my $self = shift;
    my ($path, $bounding_box) = @_;
    
    my ($n_lo, $n_hi) = $path->rect_to_n_range(@$bounding_box);
    return ($n_lo .. $n_hi);
}

sub process_polyline {}

sub fill_surface {
    my $self = shift;
    my ($surface, %params) = @_;
    
    # rotate polygons
    my $expolygon = $surface->expolygon;
    my $rotate_vector = $self->infill_direction($surface);
    $self->rotate_points($expolygon, $rotate_vector);
    
    my $distance_between_lines = $params{flow_width} / $Slic3r::resolution / $params{density} * $self->multiplier;
    my $bounding_box = [ bounding_box(map @$_, $expolygon) ];
    
    (ref $self) =~ /::([^:]+)$/;
    my $path = "Math::PlanePath::$1"->new;
    my @n = $self->get_n($path, [map +($_ / $distance_between_lines), @$bounding_box]);
    
    my $polyline = Slic3r::Polyline->cast([
        map [ map {$_*$distance_between_lines} $path->n_to_xy($_) ], @n,
    ]);
    return [] if !@{$polyline->points};
    
    $self->process_polyline($polyline, $bounding_box);
    
    my @paths = ($polyline->clip_with_expolygon($expolygon));
    
    if (0) {
        require "Slic3r/SVG.pm";
        Slic3r::SVG::output(undef, "fill.svg",
            polygons => $expolygon,
            polylines => [map $_->p, @paths],
        );
    }
    
    @paths = map $_->p, @paths;
    
    # paths must be rotated back
    $self->rotate_points_back(\@paths, $rotate_vector);
    
    return @paths;
}

1;