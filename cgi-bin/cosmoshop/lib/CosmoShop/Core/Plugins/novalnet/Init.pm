### CosmoShop Novalnet Package
### $Author: Novalnet $
### $Date: 2019-04-09 $

package CosmoShop::Core::Plugins::novalnet::Init;
use strict;

sub new {
    return bless {}, shift;
}

sub isFrontendActive { ## if a plugin isn't fully configured or for backend purposes only return a 0 to prevent unnecessary initialization
    return 0 unless ($main::Setup->novalnet_product_activation_key);
    return 0 unless ($main::Setup->novalnet_vendor_id);
    return 0 unless ($main::Setup->novalnet_auth_code);
    return 0 unless ($main::Setup->novalnet_product_id);
    return 0 unless ($main::Setup->novalnet_tariff_id);
    return 0 unless ($main::Setup->novalnet_access_key);
    return $main::CosmoShop->Payment->pluginUsed('novalnet');
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getDescription
    Parameters  : $language
    Returns     : string
    Description : To get the description text
=cut

sub getDescription {
    my $self = shift;
    my $language = shift;
    if($language eq 'de') {
        return 'Bevor Sie beginnen, lesen Sie bitte die Installationsanleitung und melden Sie sich mit Ihrem Händlerkonto im <a href="https://admin.novalnet.de" target="_blank">Novalnet Admin-Portal </a>an. Um ein Händlerkonto zu erhalten, senden Sie bitte eine E-Mail an <a href="mailto:sales@novalnet.de">sales@novalnet.de</a> oder rufen Sie uns unter +49 89 923068320 an.<br><br>Um PayPal-Transaktionen zu akzeptieren, konfigurieren Sie Ihre PayPal-API-Informationen im <a href="https://admin.novalnet.de" target="_blank">Novalnet Admin-Portal</a> > PROJEKT > Wählen Sie Ihr Projekt > Zahlungsmethoden > Paypal > Konfigurieren ';
    }
    return 'Please read the Installation Guide before you start and login to the <a href="https://admin.novalnet.de" target="_blank">Novalnet Admin Portal</a> using your merchant account. To get a merchant account, mail to <a href="mailto:sales@novalnet.de">sales@novalnet.de </a>or call +49 (089) 923068320.<br><br>To accept PayPal transactions, configure your PayPal API info in the <a href="https://admin.novalnet.de" target="_blank">Novalnet Admin Portal</a> > PROJECT > "Project" Information > Payment Methods > Paypal > Configure.';
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getHeaderText
    Parameters  : none
    Returns     : string
    Description : To get the header text
=cut

sub getHeaderText {
    my $self = shift;
    my $language = $main::CosmoShop->getBackendLanguage();

    my $scriptUrl = $main::CosmoShop->getObject('Structure')->getSharedHtmlDir({asUrl => 1}) .'/novalnet/js/novalnet_admin.js';

    return $self->getDescription($language).
    qq~<script src="$scriptUrl"></script>~;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getFooterText
    Parameters  : $language
    Returns     : string
    Description : To get the footer text
=cut

sub getFooterText {
    return '';
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getSetup
    Parameters  : none
    Returns     : array
    Description : To setup the novalnet fields in the configuration
=cut

sub getSetup {
    my $self = shift;

    return [
        ### Global Configuration ###
        $self->setSection( 'novalnet_global' ),
        $self->setConfiguration( 'novalnet_product_activation_key', '','', '1' ),
        $self->setConfiguration( 'novalnet_vendor_id', 'int', '', '1' ),
        $self->setConfiguration( 'novalnet_auth_code', '', '', '1' ),
        $self->setConfiguration( 'novalnet_product_id', 'int', '', '1' ),
        $self->setConfiguration( 'novalnet_tariff_id', '', '', '1'),
        $self->setConfiguration( 'novalnet_access_key', '', '', '1' ),
        $self->setConfiguration( 'novalnet_display_payment_logo','bool', '1', ''),
        $self->setOrderStatusConfiguration( 'novalnet_onhold_order_complete', '1'),
        $self->setOrderStatusConfiguration( 'novalnet_onhold_order_cancelled', '3'),

        ### Callback Configuration ###
        $self->setSection( 'novalnet_callback' ),
        $self->setConfiguration( 'novalnet_callback_test_mode','bool', '0', ''),
        $self->setConfiguration( 'novalnet_callback_mail_send', 'bool','0', ''),

        $self->setConfiguration( 'novalnet_callback_mail_to', '', '', ''),
        $self->setConfiguration( 'novalnet_notify_url', '',$main::CosmoShop->getScriptUrl({ssl => 1}) . '?action=handle_novalnet_notify', ''),


        ### Credit card Configuration ###
        $self->setSection( 'novalnet_cc' ),
        $self->setConfiguration( 'novalnet_cc_test_mode', 'bool', '', ''),
        $self->setSelectConfiguration( 'novalnet_cc_transaction_type', 'capture', {'capture'=>'Capture','authorize'=>'Authorize'} ),
        $self->setConfiguration( 'novalnet_cc_manual_limit', 'int', '', '' ),
        $self->setConfiguration( 'novalnet_cc_3d', 'bool', '', '' ),
        $self->setConfiguration( 'novalnet_cc_force_redirect', 'bool', '', '' ),
        $self->setConfiguration( 'novalnet_cc_amex_logo', 'bool', '', '' ),
        $self->setConfiguration( 'novalnet_cc_mastero_logo', 'bool', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_cc_order_status', '9' ),
        $self->setConfiguration( 'novalnet_cc_notify_buyer', '', '', '' ),
        $self->setSection( 'novalnet_cc_css' ),
        $self->setConfiguration( 'novalnet_cc_iframe_label', 'text', ''),
        $self->setConfiguration( 'novalnet_cc_iframe_input', 'text', ''),
        $self->setConfiguration( 'novalnet_cc_iframe_css', 'text', '.input-group{text-transform: uppercase;font-size: 14px;font-weight: 800;float: left;font-family: Open Sans Condensed,sans-serif;color: #424245;}.label-group{text-transform: uppercase;font-size: 14px;font-weight: 800;float: left;font-family: Open Sans Condensed,sans-serif;color: #424245;}'),

        ### Direct Debit SEPA Configuration ###
        $self->setSection( 'novalnet_sepa' ),
        $self->setConfiguration( 'novalnet_sepa_test_mode', 'bool', '', '' ),
        $self->setSelectConfiguration( 'novalnet_sepa_transaction_type', 'capture', {'capture'=>'Capture','authorize'=>'Authorize'} ),
        $self->setConfiguration( 'novalnet_sepa_manual_limit', 'int', '', '' ),
        $self->setConfiguration( 'novalnet_sepa_due_date', 'int', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_sepa_order_status', '9' ),
        $self->setConfiguration( 'novalnet_sepa_notify_buyer', '', '', '' ),
        $self->setSection( 'novalnet_sepa_guaranteed'),
        $self->setConfiguration( 'novalnet_sepa_guarantee_payment','bool', '0', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_sepa_guarantee_order_pending_status', '8' ),
        $self->setConfiguration( 'novalnet_sepa_guaruntee_minimum', '', '', '' ),
        $self->setConfiguration( 'novalnet_sepa_force_guarantee_payment','bool', '0', '' ),

        ### Invoice Configuration ###
        $self->setSection( 'novalnet_invoice'),
        $self->setConfiguration( 'novalnet_invoice_test_mode', 'bool', '', '' ),
        $self->setSelectConfiguration( 'novalnet_invoice_transaction_type', 'capture', {'capture'=>'Capture','authorize'=>'Authorize'} ),
        $self->setConfiguration( 'novalnet_invoice_manual_limit', 'int', '', '' ),
        $self->setConfiguration( 'novalnet_invoice_due_date', 'int', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_invoice_order_status', '1' ),
        $self->setOrderStatusConfiguration( 'novalnet_invoice_callback_status', '9' ),
        $self->setConfiguration( 'novalnet_invoice_notify_buyer', '', '', '' ),
        $self->setSection( 'novalnet_invoice_guaranteed'),
        $self->setConfiguration( 'novalnet_invoice_guarantee_payment', 'bool', '0', ''),
        $self->setOrderStatusConfiguration( 'novalnet_invoice_guarantee_order_pending_status', '8' ),
        $self->setConfiguration( 'novalnet_invoice_guaruntee_minimum', '', '', ''),
        $self->setConfiguration( 'novalnet_invoice_force_guarantee_payment', 'bool','0', ''),

        ### Prepayment Configuration ###
        $self->setSection( 'novalnet_prepayment'),
        $self->setConfiguration( 'novalnet_prepayment_test_mode', 'bool', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_prepayment_order_status', '1' ),
        $self->setOrderStatusConfiguration( 'novalnet_prepayment_callback_status', '9' ),
        $self->setConfiguration( 'novalnet_prepayment_notify_buyer', '', '', '' ),

        ### PayPal Configuration ###
        $self->setSection( 'novalnet_paypal' ),
        $self->setConfiguration( 'novalnet_paypal_test_mode', 'bool', '', '' ),
        $self->setSelectConfiguration( 'novalnet_paypal_transaction_type', 'capture', {'capture'=>'Capture','authorize'=>'Authorize'} ),
        $self->setConfiguration( 'novalnet_paypal_manual_limit', 'int', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_paypal_order_status', '9' ),
        $self->setOrderStatusConfiguration( 'novalnet_paypal_order_pending_status', '8' ),
        $self->setConfiguration( 'novalnet_paypal_notify_buyer', '', '', '' ),

        ### eps Configuration ###
        $self->setSection( 'novalnet_eps' ),
        $self->setConfiguration( 'novalnet_eps_test_mode', 'bool', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_eps_order_status', '9' ),
        $self->setConfiguration( 'novalnet_eps_notify_buyer', '', '', '' ),

        ### iDeal Configuration ###
        $self->setSection( 'novalnet_ideal' ),
        $self->setConfiguration( 'novalnet_ideal_test_mode', 'bool', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_ideal_order_status', '9' ),
        $self->setConfiguration( 'novalnet_ideal_notify_buyer', '', '', '' ),

        ### sofort Configuration ###
        $self->setSection( 'novalnet_instantbank' ),
        $self->setConfiguration( 'novalnet_instantbank_test_mode', 'bool', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_instantbank_order_status', '9' ),
        $self->setConfiguration( 'novalnet_instantbank_notify_buyer', '', '', '' ),

        ### giropay Configuration ###
        $self->setSection( 'novalnet_giropay' ),
        $self->setConfiguration( 'novalnet_giropay_test_mode', 'bool', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_giropay_order_status', '9' ),
        $self->setConfiguration( 'novalnet_giropay_notify_buyer', '', '', '' ),

        ### przelewy24 Configuration ###
        $self->setSection( 'novalnet_przelewy24' ),
        $self->setConfiguration( 'novalnet_przelewy24_test_mode', 'bool', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_przelewy24_order_status', '9' ),
        $self->setOrderStatusConfiguration( 'novalnet_przelewy24_order_pending_status', '8' ),
        $self->setConfiguration( 'novalnet_przelewy24_notify_buyer', '', '', '' ),
        
        ### barzahlen Configuration ###
        $self->setSection( 'novalnet_cashpayment' ),
        $self->setConfiguration( 'novalnet_cashpayment_test_mode', 'bool', '', '' ),
        $self->setConfiguration( 'novalnet_cashpayment_due_date', 'int', '', '' ),
        $self->setOrderStatusConfiguration( 'novalnet_cashpayment_order_status', '9' ),
        $self->setOrderStatusConfiguration( 'novalnet_cashpayment_callback_status', '8' ),
        $self->setConfiguration( 'novalnet_cashpayment_notify_buyer', '', '', '' ),
        {
            name => 'novalnet_save_function',
            default => 0,
            ftype => 'saveFunction',
            fname => \&saveFunction,
        },
    ];
}

#/////////////////////////////////////////////////////////////////////////////

=head2 saveFunction
    Parameters  : $newValues
    Parameters  : $errors
    Parameters  : $wrongValues
    Returns     : none
    Description : To validate and save the field while save the configuration
=cut

sub saveFunction {
    my $newValues = shift || {};
    my $errors = shift || {};
    my $wrongValues = shift || {};
    my @Payment_method = ('novalnet_invoice','novalnet_prepayment','novalnet_cashpayment','novalnet_sepa','novalnet_cc','novalnet_paypal', 'novalnet_ideal', 'novalnet_instantbank', 'novalnet_eps', 'novalnet_giropay','novalnet_przelewy24');
    my $language = $main::CosmoShop->getBackendLanguage();
    
    foreach my $payment(@Payment_method)
    {
		if($newValues->{$payment.'_notify_buyer'} ne '')
		{
			$newValues->{$payment.'_notify_buyer'} =~ s/<[^>]*>//gs;
		}
	}
	
    if(! $newValues->{novalnet_product_activation_key}) {
        $errors->{novalnet_product_activation_key} = ($language eq 'de') ? 'Füllen Sie bitte alle Pflichtfelder aus.' : 'Please fill in all the mandatory fields';
        $wrongValues->{novalnet_product_activation_key} = $newValues->{novalnet_product_activation_key};
    }elsif(! $newValues->{novalnet_tariff_id}) {
        $errors->{novalnet_tariff_id} = ($language eq 'de') ? 'Füllen Sie bitte alle Pflichtfelder aus.' : 'Please fill in all the mandatory fields';
        $wrongValues->{novalnet_tariff_id} = $newValues->{novalnet_tariff_id};
    }elsif($newValues->{novalnet_sepa_due_date} ne '' && ($newValues->{novalnet_sepa_due_date} < 2 || $newValues->{novalnet_sepa_due_date} > 14)) {
        $errors->{'novalnet_sepa_due_date'} = ($language eq 'de') ? 'SEPA Fälligkeitsdatum Ungültiger' : 'SEPA Due date is not valid';
        $wrongValues->{novalnet_sepa_due_date} = '';
    } elsif($newValues->{novalnet_sepa_guaruntee_minimum} ne '' && $newValues->{novalnet_sepa_guaruntee_minimum} < 999) {
        $errors->{'novalnet_sepa_guaruntee_minimum'} = ($language eq 'de') ? 'Der Mindestbetrag sollte bei mindestens 9,99 EUR' : 'The minimum amount should be at least 9,99 EUR';
        $wrongValues->{novalnet_sepa_guaruntee_minimum} = '';
    } elsif($newValues->{novalnet_invoice_guaruntee_minimum} ne '' && $newValues->{novalnet_invoice_guaruntee_minimum} < 999) {
        $errors->{'novalnet_invoice_guaruntee_minimum'} = ($language eq 'de') ? 'Der Mindestbetrag sollte bei mindestens 9,99 EUR' : 'The minimum amount should be at least 9,99 EUR';
        $wrongValues->{novalnet_invoice_guaruntee_minimum} = '';
    } elsif ($newValues->{'novalnet_cc_iframe_label'} ne '')
	{
		$newValues->{'novalnet_cc_iframe_label'} =~ s/<[^>]*>//gs;
			
	} elsif ($newValues->{'novalnet_cc_iframe_css'} ne '')
	{
		$newValues->{'novalnet_cc_iframe_cc'} =~ s/<[^>]*>//gs;
	} elsif ($newValues->{'novalnet_cc_iframe_input'} ne '')
	{
		$newValues->{'novalnet_cc_iframe_input'} =~ s/<[^>]*>//gs;
	}

}

#/////////////////////////////////////////////////////////////////////////////

=head2 novalnetOrderStatus
    Parameters  : none
    Returns     : string
    Description : Set the novalnet order status in the configuration
=cut

sub novalnetOrderStatus {
    my $OrderStati = $main::CosmoShop->getAuftragStati();
    my $values = $OrderStati->asHash();
    $values->{''} = '-';
    return $values;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setSelectConfiguration
    Parameters  : $name
    Parameters  : $default
    Parameters  : $options
    Returns     : string
    Description : Set the select fields in the configuration
=cut

sub setSelectConfiguration {
    my $self = shift;
    my ($name, $default, $options) = @_;
    my $language = $main::CosmoShop->getBackendLanguage();
    my $values  = ($language eq 'de') ? {'capture'=>'Zahlung einziehen','authorize'=>'Zahlung autorisieren'} : {'capture'=>'Capture','authorize'=>'Authorize'};
    my $status = {
        name => $name,
        default => $default,
        ftype => 'select',
        formvalues =>$values,
    };
    return $status;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setOrderStatusConfiguration
    Parameters  : $name
    Parameters  : $default
    Returns     : string
    Description : Set the order status fields in the configuration
=cut

sub setOrderStatusConfiguration {
    my $self = shift;
    my ($name, $default) = @_;
    my $status = {
        name => $name,
        default => $default,
        ftype => 'select',
        formvalues => $self->novalnetOrderStatus(),
        required  => 1,
    };
    return $status;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setSection
    Parameters  : $section_type
    Returns     : string
    Description : Set the section fields in the configuration
=cut

sub setSection {
    my $self = shift;
    my ($section_type) = @_;
    my $section ={
        name => 'section_' . $section_type,
        ftype => 'comment',
    };
    return $section;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setConfiguration
    Parameters  : $name
    Parameters  : $type
    Parameters  : $default
    Parameters  : $required
    Returns     : string
    Description : Set the congiuration fields
=cut

sub setConfiguration {
    my $self = shift;
    my ($name, $type, $default, $required) = @_;

    my $configuration = {
        name     => $name,
        default  => $default,
        ftype    => $type,
        required => $required,
    };
    return $configuration;
}

1;
