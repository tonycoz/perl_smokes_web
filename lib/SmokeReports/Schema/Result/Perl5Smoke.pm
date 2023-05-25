package SmokeReports::Schema::Result::Perl5Smoke;
use v5.32.0;
use parent qw/DBIx::Class::Core/;
use SmokeReports::Sensible;

__PACKAGE__->table('perl5_smokedb');
__PACKAGE__->add_columns(qw/id raw_report report_id fetched_at/);
__PACKAGE__->set_primary_key("id");

# horribly hacky adaption from Perl5::CoreSmokeDB::Schema::Result::Report

my %io_env_order_map = (
    minitest => 1,
    stdio    => 2,
    perlio   => 3,
    locale   => 4,
    );
my $max_io_envs = scalar(keys %io_env_order_map);

sub title ($self) {
    my $br = $self->base_report;
    return join( " ",
		 "Smoke",
		 
		 @{$br}{qw(git_describe summary osname osversion cpu_description cpu_count)}
	);
}

sub _c_compilers ($js) {
    my %c_compiler_seen;
    my $i = 1;
    for my $config (@{$js->{configs}}) {
	$c_compiler_seen{$config->{c_compiler_key}} //= {
	    index     => $i++,
	    key       => $config->{c_compiler_key},
	    cc        => $config->{cc},
	    ccversion => $config->{ccversion},
	};
    }
    return [
	sort {
	    $a->{index} <=> $b->{index}
	} values %c_compiler_seen
	];
}

sub _matrix ($js) {
    my %c_compilers = map {
	$_->{key} => $_
    } @{$js->{c_compilers}};

    my (%matrix, %cfg_order, %io_env_seen);
    my $o = 0;
    for my $config ($js->{configs}->@*) {
	for my $result ($config->{results}->@*) {
	    my $cc_index = $c_compilers{$config->{c_compiler_key}}{index};

	    $matrix{$cc_index}{$config->{debugging}}{$config->{arguments}}{$result->{io_env}} =
		$result->{summary};
	    $io_env_seen{$result->{io_env}} = $result->{locale};
	}
	$cfg_order{$config->{arguments}} //= $o++;
    }

    my @io_env_in_order = sort {
	$io_env_order_map{$a} <=> $io_env_order_map{$b}
    } keys %io_env_seen;

    my @cfg_in_order = sort {
	$cfg_order{$a} <=> $cfg_order{$b}
    } keys %cfg_order;

    my @matrix;
    for my $cc (sort { $a->{index} <=> $b->{index} } values %c_compilers) {
	my $cc_index = $cc->{index};
	for my $cfg (@cfg_in_order) {
	    next if !exists($matrix{$cc_index}{N}{$cfg})
		&& !exists($matrix{$cc_index}{D}{$cfg});
	    my @line;
	    for my $debugging (qw/ N D /) {
		for my $io_env (@io_env_in_order) {
		    push(
			@line,
			$matrix{$cc_index}{$debugging}{$cfg}{$io_env} || '-'
			);
		}
	    }
	    while (@line < 8) { push @line, " " }
	    my $mline = join("  ", @line);
	    push @matrix, "$mline  $cfg (\*$cc_index)";
	}
    }
    my @legend = _matrix_legend($js,
	[
	 map { $io_env_seen{$_} ? "$_:$io_env_seen{$_}" : $_ }
	 @io_env_in_order
	]
	);
    return [ @matrix, @legend ];
}

sub _matrix_legend ($js, $io_envs) {
    my @legend = (
	(map "$_ DEBUGGING", reverse @$io_envs),
	(reverse @$io_envs)
	);
    my $first_line = join("  ", ("|") x @legend);

    my $length = (3 * 2 * $max_io_envs) - 2;
    for my $i (0 .. $#legend) {
	my $bar_count = scalar(@legend) - $i;
	my $prefix = join("  ", ("|") x $bar_count);
	$prefix =~ s/(.*)\|$/$1+/;
	my $dash_count = $length - length($prefix);
	$prefix .= "-" x $dash_count;
	$legend[$i] = "$prefix  $legend[$i]"
    }
    unshift @legend, $first_line;
    return @legend;
}

sub _test_failures ($js) {
    return _group_tests_by_status($js, 'FAILED');
}

sub _test_todo_passed ($js) {
    return _group_tests_by_status($js, 'PASSED');
}

sub _group_tests_by_status ($js, $group_status) {
    use Data::Dumper; $Data::Dumper::Indent = 1; $Data::Dumper::Sortkeys = 1;

    my %c_compilers = map {
	$_->{key} => $_
    } @{$js->{c_compilers}};

    my (%tests);
    my $max_name_length = 0;
    for my $config ($js->{configs}->@*) {
	for my $result ($config->{results}->@*) {
	    for my $io_env ($result->{failures}->@*) {
		for my $test ($io_env->{failure}) {
		    next if $test->{status} !~ /^\Q$group_status\E\b/;

		    $max_name_length = length($test->{test})
			if length($test->{test}) > $max_name_length;

		    my $key = $test->{test} . $test->{extra};
		    push(
			@{$tests{$key}{$config->{full_arguments}}{test}}, {
			    test_env => $result->{test_env},
			    test     => $test,
			}
			);
		}
	    }
	}
    }
    my @grouped_tests;
    for my $group (values %tests) {
	push @grouped_tests, {test => undef, configs => [ ]};
	for my $cfg (keys %$group) {
	    push @{ $grouped_tests[-1]->{configs} }, {
		arguments => $cfg,
		io_envs   => join("/", map $_->{test_env}, @{ $group->{$cfg}{test} })
	    };
	    $grouped_tests[-1]{test} //= $group->{$cfg}{test}[0]{test};
	}
    }
    return \@grouped_tests;
}

sub _duration_in_hhmm ($js) {
    return _time_in_hhmm($js->{duration});
}

sub _average_in_hhmm ($js) {
    return _time_in_hhmm($js->{duration} / $js->{config_count});
}

sub _time_in_hhmm {
    my $diff = shift;

    # Only show decimal point for diffs < 5 minutes
    my $digits = $diff =~ /\./ ? $diff < 5*60 ? 3 : 0 : 0;
    my $days = int( $diff / (24*60*60) );
    $diff -= 24*60*60 * $days;
    my $hour = int( $diff / (60*60) );
    $diff -= 60*60 * $hour;
    my $mins = int( $diff / 60 );
    $diff -=  60 * $mins;
    $diff = sprintf "%.${digits}f", $diff;

    my @parts;
    $days and push @parts, sprintf "%d day%s",   $days, $days == 1 ? "" : 's';
    $hour and push @parts, sprintf "%d hour%s",  $hour, $hour == 1 ? "" : 's';
    $mins and push @parts, sprintf "%d minute%s",$mins, $mins == 1 ? "" : 's';
    $diff && !$days && !$hour and push @parts, "$diff seconds";

    return join " ", @parts;
}

sub base_report ($self) {
    require Cpanel::JSON::XS;

    return Cpanel::JSON::XS->new->utf8->decode($self->raw_report);
}

sub full_report ($self) {
    my $js = $self->base_report;
    
    for my $config ($js->{configs}->@*) {
	$config->{full_arguments} =
	    $config->{debugging} eq "D"
	    ? "$config->{arguments} DEBUGGING"
	    : $config->{arguments};
	$config->{c_compiler_key} =
	    "$config->{cc}##$config->{ccversion}";
	$config->{c_compiler_label} =
	    "$config->{cc} - $config->{ccversion}";
	$config->{c_compiler_pair} =
	{
	    value => $config->{c_compiler_key},
	    label => $config->{c_compiler_label},
	};
	for my $result ($config->{results}->@*) {
	    $result->{test_env} = $result->{locale} ? "$result->{io_env}:$result->{locale}" : $result->{io_env};
	}
    }
    $js->{c_compilers} = _c_compilers($js);
    $js->{matrix} = _matrix($js);
    #$js->{matrix_legend} = _matrix_legend($js);
    $js->{test_failures} = _test_failures($js);
    $js->{test_todo_passed} = _test_todo_passed($js);
    $js->{duration_in_hhmm} = _duration_in_hhmm($js);
    $js->{average_in_hhmm} = _average_in_hhmm($js);

    $js;
}

1;
