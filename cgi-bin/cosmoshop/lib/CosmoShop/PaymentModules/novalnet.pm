package CosmoShop::PaymentModules::novalnet;
use base CosmoShop::PaymentModules::Interface;
use CosmoShop::Utils::Array;
use CosmoShop::Utils::DateTime;
use strict;
use Digest::MD5;
use MIME::Base64;

#/////////////////////////////////////////////////////////////////////////////

=head2 registerUsages
    Parameters  : PaymentModules
    Returns     : none
    Description : hook registerUsages : To define novalnet payment method with names.
=cut

sub registerUsages {
    shift;
    my $PaymentModules = shift;

    my @nn_payments = ('novalnet_prepayment', 'novalnet_invoice', 'novalnet_cc', 'novalnet_sepa', 'novalnet_paypal', 'novalnet_ideal', 'novalnet_instantbank', 'novalnet_eps', 'novalnet_giropay','novalnet_przelewy24', 'novalnet_cashpayment');
    foreach my $payments (@nn_payments) {
        $PaymentModules->registerUsage(
            { plugin => "novalnet", kennung => $payments, beschriftung => $payments . '_module_label' }
        );
    }
}

#/////////////////////////////////////////////////////////////////////////////

=head2 isBirthdayMandatory
    Parameters  : none
    Returns     : bool
    Description : To check the Birthday is Mandatory.
=cut

sub isBirthdayMandatory{
    return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getPaymentBlock
    Parameters  : shift
    Returns     : payment block
    Description : To build payment block.
=cut

sub getPaymentBlock {

	shift;
    my $kennung = shift;
    my ( $zahlung_block, $script ) = '';
	
	my $Order = $main::CosmoShop->getOrder();
    my @direct_method   = ('novalnet_prepayment', 'novalnet_invoice');
    my @redirect_method = ('novalnet_paypal', 'novalnet_ideal', 'novalnet_instantbank', 'novalnet_eps', 'novalnet_giropay','novalnet_przelewy24');
    my @form_method     = ('novalnet_sepa','novalnet_cc');
    my @slip_payment_method = ('novalnet_cashpayment');
    
    push (@redirect_method, 'novalnet_cc') if ($main::Setup->novalnet_cc_3d || $main::Setup->novalnet_cc_force_redirect);
    
    my ( %params, %Platzhalter, $paymentName) ;
	
	my $signature 		= encode_base64("vendor=".$main::Setup->getSetupParameter('novalnet_vendor_id')."&product=".$main::Setup->getSetupParameter('novalnet_product_id')."&server_ip=".$ENV{SERVER_ADDR});
	my $iframeurl 		= 'https://secure.novalnet.de/cc?api=' . $signature . '&ln=' . $main::CosmoShop->getLanguage();
	my $Order           = $main::CosmoShop->getOrder();
	setGuaranteePayment($Order, $kennung);
	
    if (grep (/^$kennung$/, @direct_method)) {
        
        %Platzhalter = ('novalnet_payment_inv_prepayment' => 1);
		$Platzhalter{'novalnet_invoice'} = 1 if($kennung eq 'novalnet_invoice');
    } elsif (grep (/^$kennung$/, @redirect_method)) {
        
        if($kennung eq 'novalnet_cc')
        {
			%Platzhalter = (
				'novalnet_payment_cc' 	=> 1,
				'novalnet_iframe_url'	=> $iframeurl,
				'novalnet_cc_label'	 	=> $main::Setup->getSetupParameter('novalnet_cc_iframe_label'),
				'novalnet_cc_input'	 	=> $main::Setup->getSetupParameter('novalnet_cc_iframe_input'),
				'novalnet_cc_css'	 	=> $main::Setup->getSetupParameter('novalnet_cc_iframe_css'),
				'novalnet_cc_redirect'	=> 1,
			);
		}
		
		$Platzhalter{'novalnet_payment_redirect'} = 1;
        my %req_params = &main::getRequestParams();
        $script				= &main::getRequestUrl($kennung);
        my @request_params;
        while( my( $name, $value ) = each %req_params){
            my %this_value = (name => $name, value => $value);
            push @request_params, \%this_value;
        }
        $Platzhalter{'shared'}         = $main::CosmoShop->getObject('Structure')->getSharedHtmlDir({asUrl => 1});
        $Platzhalter{'request_params'} = \@request_params;
    
    } elsif (grep (/^$kennung$/, @form_method)) {
		
        my $billing_address  = $Order->getInvoiceAddress();
        my $name             = $billing_address->{vorname} .' '. $billing_address->{nachname};
		
        %Platzhalter = (
            'novalnet_ac_error'      => &main::getTranslatText('novalnet_ac_error'),
            'novalnet_sepa_holder'   => $name,
            'novalnet_iframe_url'	 => $iframeurl,
            'novalnet_cc_label'	 	 => $main::Setup->getSetupParameter('novalnet_cc_iframe_label'),
			'novalnet_cc_input'	 	 => $main::Setup->getSetupParameter('novalnet_cc_iframe_input'),
			'novalnet_cc_css'	 	 => $main::Setup->getSetupParameter('novalnet_cc_iframe_css')
        );
		
        if($kennung eq 'novalnet_cc')
        {
			$Platzhalter{'novalnet_payment_cc'} = 1;
		}else{
			$Platzhalter{'novalnet_payment_sepa'} = 1;
		}
    } elsif (grep (/^$kennung$/, @slip_payment_method)) {
		%Platzhalter = ('novalnet_payment_barzahlen' => 1);
	}
    
    # Check whether we need to show dob field for Guarantee payment or not
    if($kennung =~ /^novalnet_(?:sepa|invoice)$/) {
        my $invoiceAddress = $Order->getInvoiceAddress();
        my $session = $main::CosmoShop->getSession();
        
        if( $session->getVar($kennung . "_show_dob") ) {
			$invoiceAddress->{geburtsdatum} = CosmoShop::Utils::DateTime::formatDatabaseDate($invoiceAddress->{geburtsdatum});
			$invoiceAddress->{geburtsdatum} =~ tr/./-/;
			$Platzhalter{'dob_value'} = $invoiceAddress->{geburtsdatum};
            $Platzhalter{$kennung . '_show_dob'} = 1 ;            
        } elsif($session->getVar($kennung . '_guarantee_payment_error')) {
            $Platzhalter{$kennung . '_guarantee_payment_error'} = $session->getVar($kennung . '_guarantee_payment_error');
            $Platzhalter{$kennung . '_guarantee_payment_error_message'} = $session->getVar($kennung . '_guarantee_payment_error_message');
        }
    }
    
    $Platzhalter{'novalnet_test_mode'} = $main::Setup->getSetupParameter($kennung.'_test_mode');
    $Platzhalter{'payment_name'} = $Order->getPaymentName(),;
    $Platzhalter{'novalnet_display_logo'} = $main::Setup->getSetupParameter('novalnet_display_payment_logo');
    $Platzhalter{'novalnet_logo_url'} = $main::CosmoShop->getObject('Structure')->getUserHtmlDir({asUrl => 1, ssl => 1})."/pix/user_img/novalnet_payment/".$kennung.".png";
    $Platzhalter{'novalnet_cc_logo_url'} = $main::CosmoShop->getObject('Structure')->getUserHtmlDir({asUrl => 1, ssl => 1})."/pix/user_img/novalnet_payment/novalnet_cc_master_card.png";
    if($main::Setup->getSetupParameter('novalnet_cc_amex_logo') eq 1)
	{
		$Platzhalter{'novalnet_cc_amex_logo_url'} = $main::CosmoShop->getObject('Structure')->getUserHtmlDir({asUrl => 1, ssl => 1})."/pix/user_img/novalnet_payment/novalnet_cc_amex.png";
	}
		
	if($main::Setup->getSetupParameter('novalnet_cc_mastero_logo') eq 1)
	{
		$Platzhalter{'novalnet_cc_mastero_logo_url'} = $main::CosmoShop->getObject('Structure')->getUserHtmlDir({asUrl => 1, ssl => 1})."/pix/user_img/novalnet_payment/novalnet_cc_maestro.png";
	}
    ($Platzhalter{'novalnet_notify_buyer'} = $main::Setup->getSetupParameter($kennung.'_notify_buyer')) =~ s/<[^>]*>//gs;

    my $TemplateEngine = $main::CosmoShop->getTemplateEngine();
    $zahlung_block = $TemplateEngine->render({type => "checkout_content_component", template => "novalnet_zahlungsschnittstelle", params => {Platzhalter => \%Platzhalter}});

    %params = (
        zahlung_block         => $zahlung_block,
        action                => 'handle_novalnet_payment',
        anzeigen_hiddenfields => 1,
        script                => $script,
    );
    return \%params;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 checkSelection
    Parameters  : shift
    Returns     : bool
    Description : To check the selected payment is valid or not
=cut

sub checkSelection {
    my $self    = shift;
    my %params;
    my $nn_check_param = &main::getMerchantDetails(\%params);
    my $payment_method = @_;
    return $nn_check_param if ($nn_check_param ne 1);
    return $self->SUPER::checkSelection();
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setGuaranteePayment
    Parameters  : $Order
    Parameters  : $usage
    Returns     : none
    Description : Set Guarantee payment process.
=cut

sub setGuaranteePayment {
    my ($Order, $usage) = @_;
	
    # Check for the guaranteed payment enable or not#
	my $billingAddress = $Order->getInvoiceAddress();
	my $session = $main::CosmoShop->getSession();
    if ($main::Setup->getSetupParameter( $usage . '_guarantee_payment' ) eq '1') {
        my $minimumGuaranteeAmount = $main::Setup->getSetupParameter( $usage . '_guaruntee_minimum' ) || '999';
        my $orderAmount = sprintf("%.02f", $Order->getOrderTotalGross()) * 100;
	
        # Check for same billing and shipping address#
        my $sameAddress = defined ($Order->getDeliveryAddress()) && ! CosmoShop::Utils::Array::equal(getAddress( $billingAddress ), getAddress( $Order->getDeliveryAddress() ) ) ? '0' : '1';
			
        my $error = '';
	
        if($billingAddress->{land_iso2} !~ /^(?:AT|DE|CH)$/) { # Allowed countries: AT, DE & CH
            $error = &main::getTranslatText('error_novalnet_allowed_countries_text');
            $session->unsetVars($usage . "_guarantee_payment");
            $session->unsetVars($usage . "_show_dob");
        } elsif($Order->getMainData()->{currency} ne 'EUR') { # Allowed currency: EUR
            $error = &main::getTranslatText('error_novalnet_allowed_currency_text');
            $session->unsetVars($usage . "_guarantee_payment");
            $session->unsetVars($usage . "_show_dob");
        } elsif($sameAddress ne '1') { # The billing address must be same as the shipping address
            $error = &main::getTranslatText('error_novalnet_address_text');
            $session->unsetVars($usage . "_guarantee_payment");
            $session->unsetVars($usage . "_show_dob");
        } elsif($orderAmount < $minimumGuaranteeAmount) { # Minimum amount of order >=9,99 EUR
            $error = &main::getTranslatText('error_novalnet_minimum_amount_text');
            $session->unsetVars($usage . "_guarantee_payment");
            $session->unsetVars($usage . "_show_dob");
        }
		
        if(!$error) {
			# Set Gurantee payment session#
            $session->setVar($usage . "_guarantee_payment", 1);
            $session->unsetVars($usage . "_guarantee_payment_error");
            $session->unsetVars($usage . "_guarantee_payment_error_message");
            
            # Request for birth_date only when the company parameter is not present#
            if(!$billingAddress->{firma} ) {
                $session->setVar($usage . "_show_dob", 1);
            } else {
                $session->unsetVars($usage . "_show_dob");
            }

        } elsif ( $main::Setup->getSetupParameter( $usage . '_force_guarantee_payment' ) eq '1' ) {
			
			# Unset all the Gurantee related session values here
            $session->unsetVars($usage . "_guarantee_payment");
            $session->unsetVars($usage . "_guarantee_payment_error");
            $session->unsetVars($usage . "_guarantee_payment_error_message");
            $session->unsetVars($usage . "_show_dob");
            
        } else {
            $session->setVar($usage . "_guarantee_payment_error", 1);
            $session->setVar($usage . "_guarantee_payment_error_message",$error);
        }
    } else {

        # Unset all the Gurantee related session values here#
        $session->unsetVars($usage . "_guarantee_payment");
        $session->unsetVars($usage . "_guarantee_payment_error");
        $session->unsetVars($usage . "_guarantee_payment_error_message");
        $session->unsetVars($usage . "_show_dob");
    }
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getAddress
    Parameters  : $address
    Returns     : array
    Description : Get the address values from the given hash.
=cut

sub getAddress {
    my $address  = shift;
		
    my @array = [
        $address->{strasse},
        $address->{plz},
        $address->{ort},
        $address->{land_iso2},
    ];

    return @array;
}
1;
