package CosmoShop::Template::Mail::novalnet_mail;

use strict;

#/////////////////////////////////////////////////////////////////////////////

=head2 bestellmail_kunde
    Parameters  : shift
    Returns     : Platzhalter
    Description : To set placeholders values to the template.
=cut

sub bestellmail_kunde {
    shift;
    my $param = shift;

    my $Platzhalter = $param->{Platzhalter};
    return $Platzhalter;
}

1;
