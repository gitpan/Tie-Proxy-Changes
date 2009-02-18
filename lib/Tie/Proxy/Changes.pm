###############################################################################
#Changes.pm
#Last Change: 2009-02-18
#Copyright (c) 2008 Marc-Seabstian "Maluku" Lucksch
#Version 0.1
####################
#Changes.pm is published under the terms of the MIT license, which
#basically means "Do with it whatever you want". For more information, see the 
#license.txt file that should be enclosed with plasma distributions. A copy of 
#the license is (at the time of this writing) also available at
#http://www.opensource.org/licenses/mit-license.php .
###############################################################################

package Tie::Proxy::Changes;
use strict;
use warnings;
use Carp;
use overload 
             '""'=> \&getbool, 
             'bool'=>\&getbool, 
             '%{}'=>\&gethash,
             '@{}'=>\&getarray,
             'nomethod'=>\&getbool;

our $VERSION = 0.1;

#Define some object constants for better readability

my $CALLER=0;
my $INDEX=1;
my $DATA=2;
my $TIED_HASH=3;
my $TIED_ARRAY=4;

# Create a new Tie::Proxy::Changes with optional data.
sub new {
	my $class=shift;
    my $calling_obj=shift;
    my $index=shift;
	my $self=[$calling_obj,$index]; 

    # Get the current state of the value, if it is there.
    my $data=shift;
    $self->[$DATA]=$data if $data;

    # This is needed to be a reference, otherwise it would trigger overload
    # again and again (which is not good)
	bless \$self,$class;
}

# Access this object as a hashref.
sub gethash {
	my $ref=shift;
	my $self=$$ref;

    # Return the stored access if it is already there.
	return $self->[$TIED_HASH] if $self->[$TIED_HASH];

    # Check the existing data or create it (if not there)
    croak "Can't use an array as a hash" 
        if $self->[$DATA] and ref $self->[$DATA] ne "HASH";
	$self->[$DATA]={} unless $self->[$DATA];
    
    # Tie myself as a hash.
    my %h=();
	tie %h,ref $ref,$ref;
	my $x=\%h;

    # Store the tied object for faster access.
	$self->[$TIED_HASH]=$x;

	return $x;
}

# Access this object as an arrayref.
sub getarray {
	my $ref=shift;
	my $self=$$ref;

    # Return the stored access if it is already there.
	return $self->[$TIED_ARRAY] if $self->[$TIED_ARRAY];
    
    # Check the existing data or create it (if not there)
    croak "Can't use an array as a hash" 
        if $self->[$DATA] and ref $self->[$DATA] ne "ARRAY";
	$self->[$DATA]=[] unless $self->[$DATA];

    # Tie myself as an array.
	my @a=();
	tie @a,ref $ref,$ref;
	my $x=\@a;

    # Store the tied object for faster access.
	$self->[$TIED_ARRAY]=$x;

	return $x;
}

# Test for the boolean value
sub getbool {
    my $ref=shift;
	my $self=$$ref;

    # Test for data, return the size of array or hash data.
    if ($self->[$DATA]) {
        if (ref $self->[$DATA] eq "HASH") {
            return scalar %{$self->[$DATA]};
        }
        elsif (ref $self->[$DATA] eq "ARRAY") {
            return scalar @{$self->[$DATA]};
        }

        # Return other data, if it's not an array or a hash
        return $self->[$DATA];
    }

    # Empty object is always false (Happens during autovivify)
	return 0;
}

sub TIEHASH { 
	my $class=shift;
	return shift;
}
sub TIEARRAY { 
	my $class=shift;
	return shift;
}


sub STORE { 
	my $ref=shift;
	my $self=$$ref;
	my $key=shift;
	my $value=shift;
	
    # Choose the right operating method, since STORE can be called on both
    # arrays and hashes
    if (ref $self->[$DATA] eq "HASH") {
		$self->[$DATA]->{$key}=$value;
	}
	else {
		$self->[$DATA]->[$key]=$value;
	}

    # Content has changed, call STORE of the emitting object/tie.
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]);

    return;
}
sub FETCH { 
	my $ref=shift;
	my $self=$$ref;
	my $key=shift;

    # Choose the right operationg method, FETCH is also implemented for both
    # arrays and hashes.
    # This also creates a new ChangeProxy, so it can track the changes of the
    # data of this object as well. The STORE calls are stacking till they
    # reach the emitting object.
	if (ref $self->[$DATA] eq "HASH") {
		return __PACKAGE__->new($ref,$key,$self->[$DATA]->{$key}) if $self->[$DATA]->{$key};
	}
	else {
		return __PACKAGE__->new($ref,$key,$self->[$DATA]->[$key]) if $self->[$DATA]->[$key];
	}

    # Also return an empty ChangeProxy on unknown keys or indices, so
    # autovivify calls are tracked as well. The object will play empty/undef
    # in bool context, so it works for both testing and autovivification,
    # since there is no way to distinguish them from the FETCH call. 
    return __PACKAGE__->new($ref,$key); 
}

# This implements the rest of the tie interface, nothing new here, they just
# call STORE on every change to proxy them as well.

sub FIRSTKEY { 
	my $ref=shift;
	my $self=$$ref;
	my $a = scalar keys %{$self->[$DATA]}; each %{$self->[$DATA]} 
}
sub NEXTKEY  { 
	my $ref=shift;
	my $self=$$ref;
	each %{$self->[$DATA]}
}
sub EXISTS   { 
	my $ref=shift;
	my $self=$$ref;
	my $key=shift;
	if (ref $self->[$DATA] eq "HASH") {
		return exists $self->[$DATA]->{$key};
	}
	else {
		return exists $self->[$DATA]->{$key};
	}
}
sub DELETE   { 
	my $ref=shift;
	my $self=$$ref;
	my $key=shift;
	if (ref $self->[$DATA] eq "HASH") {
		delete $self->[$DATA]->{$key};
	}
	else {
		delete $self->[$DATA]->{$key};
	}
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]);
}
sub CLEAR    { 
	my $ref=shift;
	my $self=$$ref;
	if (ref $self->[$DATA] eq "HASH") {
		%{$self->[$DATA]}=();
	}
	else {
		@{$self->[$DATA]}=()
	}
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]); 
}
sub SCALAR { 
	my $ref=shift;
	my $self=$$ref;
	if (ref $self->[$DATA] eq "HASH") {
		return scalar %{$self->[$DATA]};
	}
	else {
		return scalar @{$self->[$DATA]};
	}
}

sub FETCHSIZE { 
	my $ref=shift;
	my $self=$$ref;
	scalar @{$self->[$DATA]}; 
}
sub STORESIZE { 
	my $ref=shift;
	my $self=$$ref;
	$#{$self->[$DATA]} = $_[$CALLER]-1;
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]); 
}
sub POP       { 
	my $ref=shift;
	my $self=$$ref;
	my $e=pop(@{$self->[$DATA]});
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]); 
	return $e;
}
sub PUSH      { 
	my $ref=shift;
	my $self=$$ref;
	push(@{$self->[$DATA]},@_);
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]); 
	return;
}
sub SHIFT     { 
	my $ref=shift;
	my $self=$$ref;
	my $e=shift(@{$self->[$DATA]});
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]); 
	return $e;
}
sub UNSHIFT   { 
	my $ref=shift;
	my $self=$$ref;
	unshift(@{$self->[$DATA]},@_);
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]); 
	return; }

sub SPLICE
{
	my $ref=shift;
	my $self=$$ref;
	my $sz  = scalar @{$self->[$DATA]};
	my $off = @_ ? shift : 0;
	$off   += $sz if $off < 0;
	my $len = @_ ? shift : $sz-$off;
	my @rem=splice(@{$self->[$DATA]},$off,$len,@_);
	$self->[$CALLER]->STORE($self->[$INDEX],$self->[$DATA]); 
	return @rem;
}

1;

__END__

=head1 NAME

Tie::Proxy::Changes - Track changes in your tied objects

=head1 SYNOPSIS

In any tied class:

    use Tie::Proxy::Changes;
    use Tie::Hash;
    
    our @ISA=qw/Tie::StdHash/;
   
    sub FETCH {
        my $self=shift;
        my $key=shift;
        if (exists $self->{$key}) {
            return Tie::Proxy::Changes->new($self,$key,$self->{$key});
        }
        else {
            return Tie::Proxy::Changes->new($self,$key);
        }
    }

=head1 DESCRIPTION

Sometimes a tied object needs to keep track of all changes happening to its
data. This includes substructures with multi-level data. Returning a
C<Tie::Proxy::Changes> object instead of the raw data will result in a STORE call
whenever the data is changed.

Here is a small example to illustrate to problem.

    package main;
    tie %data 'TiedObject';
    $data{FOO}={}; #Calls STORE(FOO,{})
    $data{FOO}->{Bar}=1; #calls just FETCH.

But when TiedObject is changed, it does this:

    package TiedObject;
    #...
    sub FETCH {
        my $self=shift;
        my $key=shift;
        #... $data=something.
        # return $data # Not anymore.
        return Tie::Proxy::Changes->new($self,$key,$data);
    }
    package main;
    tie %data 'TiedObject';
    $data{FOO}={}; #Calls STORE(FOO,{})
    $data{FOO}->{Bar}=1; #calls FETCH and then STORE(FOO,{Bar=>1}).


=head1 AUTOVIVIFICATION

This module can also (or exclusivly) be used to make autovivification work.
Some tied datastructures convert all mulit-level data they get into tied 
objects.

When perl gets an C<undef> from a FETCH call, it calls STORE with an empty
reference to an array or a hash and then changes that hash. Some tied objects
however can not keep this reference, because they save it in a different way.

The solution is to have FETCH return an empty C<Tie::Proxy::Changes> object, and
if the object is changed, STORE of the tied object will be called with the
given key

    my $self=shift;
    my $key=shift;
    ...
    #return undef; # Not anymore
    return Tie::Proxy::Changes->new($self,$key);

If the object is just tested for existance of substructures, no STORE is
called.

=head1 METHODS

=head2 new (OBJECT, KEY, [DATA]) 

Creates a new C<Tie::Proxy::Changes>, on every change of its content
C<OBJECT>->STORE(C<KEY>,C<MODIFIED DATA>) is called.

=head1 INTERNAL METHODS

These are used to provide the right access for L<overload> and L<tie>. They
shouldn't be called at any rate.

=head2 getarray

This gets called when C<Tie::Proxy::Changes> plays arrayref by L<overload>.

=head2 gethash

This gets called when C<Tie::Proxy::Changes> plays hash by L<overload>.

=head2 getbool

This gets called when C<Tie::Proxy::Changes> is asked if it is true or false.
Returns true if this has content and that is true.

=head2 SCALAR

Returns the size of the data.

See L<perltie> (Somehow Pod::Coverage annoys me about this method).

=head1 BUGS

This won't work if you structure contains Refernces to SCALAR or other REFs,
since overload is used, and there is no way to access the contained data if
C<@{}>, C<%{}> and C<${}> is overloaded. If you find any way, drop me a mail.

=head1 SEE ALSO

L<perltie>

=head1 LICENSE

C<Tie::Proxy::Changes> is published under the terms of the MIT license, which 
basically means "Do with it whatever you want". For more information, see the 
LICENSE file that should be enclosed with this distribution. A copy of the
license is (at the time of this writing) also available at
L<http://www.opensource.org/licenses/mit-license.php>.

=head1 AUTHOR

Marc "Maluku" Sebastian Lucksch

perl@marc-s.de

=cut


