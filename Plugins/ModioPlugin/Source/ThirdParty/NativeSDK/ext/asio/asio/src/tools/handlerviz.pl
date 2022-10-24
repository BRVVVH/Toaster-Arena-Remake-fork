#!/usr/bin/perl -w
#
# handlerviz.pl
# ~~~~~~~~~~~~~
#
# A visualisation tool for post-processing the debug output generated by
# Asio-based programs. Programs write this output to the standard error stream
# when compiled with the define `ASIO_ENABLE_HANDLER_TRACKING'.
#
# This tool generates output intended for use with the GraphViz tool `dot'. For
# example, to convert output to a PNG image, use:
#
#   perl handlerviz.pl < output.txt | dot -Tpng > output.png
#
# To convert to a PDF file, use:
#
#   perl handlerviz.pl < output.txt | dot -Tpdf > output.pdf
#
# Copyright (c) 2003-2020 Christopher M. Kohlhoff (chris at kohlhoff dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

use strict;

my %nodes = ();
my @edges = ();
my %locations = ();
my %anon_nodes = ();
my $anon_id = 0;
my %all_nodes = ();
my %pending_nodes = ();

#-------------------------------------------------------------------------------
# Parse the debugging output and populate the nodes and edges.

sub parse_debug_output()
{
  while (my $line = <>)
  {
    chomp($line);

    if ($line =~ /\@asio\|([^|]*)\|([^|]*)\|(.*)$/)
    {
      my $timestamp = $1;
      my $action = $2;
      my $description = $3;

      # Handler creation.
      if ($action =~ /^([0-9]+)\*([0-9]+)$/)
      {
        my $begin = $1;
        my $end = $2;
        my $label = $description;
        $label =~ s/\./\\n/g;

        if ($begin eq "0")
        {
          $begin = "a" . $anon_id++;
          $anon_nodes{$begin} = $timestamp;
          $all_nodes{"$timestamp-$begin"} = $begin;
        }

        my %edge = ( begin=>$begin, end=>$end, label=>$label );
        push(@edges, \%edge);

        $pending_nodes{$end} = 1;
      }

      # Handler location.
      elsif ($action =~ /^([0-9]+)\^([0-9]+)$/)
      {
        if ($1 ne "0")
        {
          if (not exists($locations{($1,$2)}))
          {
            $locations{($1,$2)} = ();
          }
          push(@{$locations{($1,$2)}}, $description);
        }
      }

      # Begin handler invocation. 
      elsif ($action =~ /^>([0-9]+)$/)
      {
        my %new_node = ( label=>$description, entry=>$timestamp );
        $new_node{content} = ();
        $nodes{$1} = \%new_node;
        $all_nodes{"$timestamp-$1"} = $1;
        delete($pending_nodes{$1});
      }

      # End handler invocation.
      elsif ($action =~ /^<([0-9]+)$/)
      {
        $nodes{$1}->{exit} = $timestamp;
      }

      # Handler threw exception.
      elsif ($action =~ /^!([0-9]+)$/)
      {
        push(@{$nodes{$1}->{content}}, "exception");
      }

      # Handler was destroyed without being invoked.
      elsif ($action =~ /^~([0-9]+)$/)
      {
        my %new_node = ( label=>"$timestamp destroyed" );
        $new_node{content} = ();
        $nodes{$1} = \%new_node;
        $all_nodes{"$timestamp-$1"} = $1;
        delete($pending_nodes{$1});
      }

      # Handler performed some operation.
      elsif ($action =~ /^([0-9]+)$/)
      {
        if ($1 eq "0")
        {
          my $id = "a" . $anon_id++;
          $anon_nodes{$id} = "$timestamp\\l$description";
          $all_nodes{"$timestamp-$id"} = $id;
        }
        else
        {
          push(@{$nodes{$1}->{content}}, "$description");
        }
      }
    }
  }
}

#-------------------------------------------------------------------------------
# Helper function to convert a string to escaped HTML text.

sub escape($)
{
  my $text = shift;
  $text =~ s/&/\&amp\;/g;
  $text =~ s/</\&lt\;/g;
  $text =~ s/>/\&gt\;/g;
  $text =~ s/\t/    /g;
  return $text;
}

#-------------------------------------------------------------------------------
# Templates for dot output.

my $graph_header = <<"EOF";
/* Generated by handlerviz.pl */
digraph "handlerviz output"
{
graph [ nodesep="1" ];
node [ shape="box", fontsize="9" ];
edge [ arrowtail="dot", fontsize="9" ];
EOF

my $graph_footer = <<"EOF";
}
EOF

my $node_header = <<"EOF";
"%name%"
[
label=<<table border="0" cellspacing="0">
<tr><td align="left" bgcolor="gray" border="0">%label%</td></tr>
EOF

my $node_footer = <<"EOF";
</table>>
]
EOF

my $node_content = <<"EOF";
<tr><td align="left" bgcolor="white" border="0">
<font face="mono" point-size="9">%content%</font>
</td></tr>
EOF

my $anon_nodes_header = <<"EOF";
{
node [ shape="record" ];
EOF

my $anon_nodes_footer = <<"EOF";
}
EOF

my $anon_node = <<"EOF";
"%name%" [ label="%label%", color="gray" ];
EOF

my $pending_nodes_header = <<"EOF";
{
node [ shape="record", color="red" ];
rank = "max";
EOF

my $pending_nodes_footer = <<"EOF";
}
EOF

my $pending_node = <<"EOF";
"%name%";
EOF

my $edges_header = <<"EOF";
{
edge [ style="dashed", arrowhead="open" ];
EOF

my $edges_footer = <<"EOF";
}
EOF

my $edge = <<"EOF";
"%begin%" -> "%end%" [ label="%label%", labeltooltip="%tooltip%" ]
EOF

my $node_order_header = <<"EOF";
{
node [ style="invisible" ];
edge [ style="invis", weight="100" ];
EOF

my $node_order_footer = <<"EOF";
}
EOF

my $node_order = <<"EOF";
{
rank="same"
"%begin%";
"o%begin%";
}
"o%begin%" -> "o%end%";
EOF

#-------------------------------------------------------------------------------
# Generate dot output from the nodes and edges.

sub print_nodes()
{
  foreach my $name (sort keys %nodes)
  {
    my $node = $nodes{$name};
    my $entry = $node->{entry};
    my $exit = $node->{exit};
    my $label = escape($node->{label});
    my $header = $node_header;
    $header =~ s/%name%/$name/g;
    $header =~ s/%label%/$label/g;
    print($header);

    if (defined($exit) and defined($entry))
    {
      my $line = $node_content;
      my $content = $entry . " + " . sprintf("%.6f", $exit - $entry) . "s";
      $line =~ s/%content%/$content/g;
      print($line);
    }

    foreach my $content (@{$node->{content}})
    {
      $content = escape($content);
      $content = " " if length($content) == 0;
      my $line = $node_content;
      $line =~ s/%content%/$content/g;
      print($line);
    }

    print($node_footer);
  }
}

sub print_anon_nodes()
{
  print($anon_nodes_header);
  foreach my $name (sort keys %anon_nodes)
  {
    my $label = $anon_nodes{$name};
    my $line = $anon_node;
    $line =~ s/%name%/$name/g;
    $line =~ s/%label%/$label/g;
    print($line);
  }
  print($anon_nodes_footer);
}

sub print_pending_nodes()
{
  print($pending_nodes_header);
  foreach my $name (sort keys %pending_nodes)
  {
    my $line = $pending_node;
    $line =~ s/%name%/$name/g;
    print($line);
  }
  print($pending_nodes_footer);
}

sub print_edges()
{
  print($edges_header);
  foreach my $e (@edges)
  {
    my $begin = $e->{begin};
    my $end = $e->{end};
    my $label = $e->{label};
    my $tooltip = "";
    if (exists($locations{($begin,$end)}))
    {
      for my $line (@{$locations{($begin,$end)}})
      {
        $tooltip = $tooltip . escape($line) . "\n";
      }
    }
    my $line = $edge;
    $line =~ s/%begin%/$begin/g;
    $line =~ s/%end%/$end/g;
    $line =~ s/%label%/$label/g;
    $line =~ s/%tooltip%/$tooltip/g;
    print($line);
  }
  print($edges_footer);
}

sub print_node_order()
{
  my $prev = "";
  print($node_order_header);
  foreach my $name (sort keys %all_nodes)
  {
    if ($prev ne "")
    {
      my $begin = $prev;
      my $end = $all_nodes{$name};
      my $line = $node_order;
      $line =~ s/%begin%/$begin/g;
      $line =~ s/%end%/$end/g;
      print($line);
    }
    $prev = $all_nodes{$name};
  }
  foreach my $name (sort keys %pending_nodes)
  {
    if ($prev ne "")
    {
      my $begin = $prev;
      my $line = $node_order;
      $line =~ s/%begin%/$begin/g;
      $line =~ s/%end%/$name/g;
      print($line);
    }
    last;
  }
  print($node_order_footer);
}

sub generate_dot()
{
  print($graph_header);
  print_nodes();
  print_anon_nodes();
  print_pending_nodes();
  print_edges();
  print_node_order();
  print($graph_footer);
}

#-------------------------------------------------------------------------------

parse_debug_output();
generate_dot();
