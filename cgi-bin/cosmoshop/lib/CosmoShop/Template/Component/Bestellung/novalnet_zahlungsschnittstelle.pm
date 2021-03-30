package CosmoShop::Template::Component::Bestellung::novalnet_zahlungsschnittstelle;

use strict;

#/////////////////////////////////////////////////////////////////////////////

=head2 novalnet_zahlungsschnittstelle
    Parameters  : shift
    Returns     : Platzhalter
    Description : To set placeholders values to the template.
=cut

sub novalnet_zahlungsschnittstelle {
    shift;
    my $param = shift;

    my $Platzhalter = $param->{Platzhalter};
    return $Platzhalter;
}

1;
