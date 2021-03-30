package CosmoShop::ActionHandler::handle_novalnet_payment;
use strict;
use Switch;
use POSIX qw(strftime);
use Digest::SHA qw(sha256_hex);
use LWP::UserAgent;

#/////////////////////////////////////////////////////////////////////////////

=head2 handle
    Parameters  : none
    Returns     : array
    Description : hook action handler.
=cut

sub handle {
    return ('bestellung_schritt_4', 'bestellung', {}) unless ($main::Setup->pluginActive('novalnet'));

    my $errortext = &main::getTranslatText('novalnet_payment_failure');

    my $Response         = $main::CosmoShop->getResponse();
    my $Order            = $main::CosmoShop->getOrder();
    my $payment_method   = $Order->getPaymentUsage();
    my $payment_name     = $Order->getPaymentName();
    my %request_params   = &main::getRequestParams();
    my $Request          = $main::CosmoShop->getRequest();
    my $in               = $Request->getParameter();
    my @hash_params 	 = ('auth_code', 'product', 'tariff', 'amount', 'test_mode','uniqid');
	my $hash;
	
    my @redirect_payments = ('novalnet_paypal', 'novalnet_ideal', 'novalnet_instantbank', 'novalnet_eps', 'novalnet_giropay','novalnet_przelewy24');
    
    push (@redirect_payments, 'novalnet_cc') if ($main::Setup->novalnet_cc_3d || $main::Setup->novalnet_cc_force_redirect);
    
    my (%response_hash, $order_status, @paid_amount , $status);

    if (grep( /^$payment_method$/, @redirect_payments )) {
        $response_hash{'response'} = $in;
    }
    else {
        my $url        = 'https://payport.novalnet.de/paygate.jsp';
        %response_hash = &main::httpRequest($url, %request_params, $payment_method);
    }
	
    if ($response_hash{'response'}{'status'} ne '100') {
        $Response->addError($errortext . '<br><b>' . $response_hash{'response'}{'status_text'} . '</b>');
        return ("bestellung_schritt_4", "bestellung", {});
    }elsif( grep( /^$payment_method$/, @redirect_payments ) )
    {
		foreach my $param (@hash_params) {
			$response_hash{'response'}{$param} =~ s/ /=/g;
			$hash .=  $response_hash{'response'}{$param};
		}
		$hash = $hash . reverse($main::Setup->novalnet_access_key);
		
		if(sha256_hex($hash) ne $response_hash{'response'}{'hash2'})
		{
			$Response->addError($errortext . '<br><b>' . &main::getTranslatText('info_novalnet_hash_check_failed') . '</b>');
			return ("bestellung_schritt_4", "bestellung", {});
		}
	}
	
	my $orderStatus = '';
    my %paymentInfos = ();
    
    $paymentInfos{'transaction_amount'} = sprintf("%.02f", $Order->getOrderTotalGross()) * 100;
    $paymentInfos{'tid_status'}         = $response_hash{'response'}{'tid_status'};
	
	# Get order status and paid amount value based on response #
    if($response_hash{'response'}{'tid_status'} eq '75') {
        $paymentInfos{'paid_amount'} = '0';
        $orderStatus = $main::Setup->getSetupParameter($payment_method . '_guarantee_order_pending_status');
    } elsif($response_hash{'response'}{'tid_status'} =~ /^(86|90)$/) {
        $paymentInfos{'paid_amount'} = '0';
        $orderStatus = $main::Setup->getSetupParameter($payment_method . '_order_pending_status');
    } elsif($response_hash{'response'}{'tid_status'} =~ /^(85|91|98|99)$/) {
        $paymentInfos{'paid_amount'} = '0';
        $orderStatus = $main::Setup->getSetupParameter('novalnet_onhold_order_complete');
    }elsif($response_hash{'response'}{'payment_id'} eq '41' && $response_hash{'response'}{'tid_status'} eq '100') {
        $paymentInfos{'paid_amount'} = $paymentInfos{'transaction_amount'};
        $Order->setPaymentConfirmed(1);
        $orderStatus = $main::Setup->getSetupParameter($payment_method . '_callback_status');
    } else {
        if($payment_method =~ /^novalnet_(?:invoice|prepayment|cashpayment)$/o) {
            $paymentInfos{'paid_amount'} = '0';
        } else {
            $paymentInfos{'paid_amount'} = $paymentInfos{'transaction_amount'};
            $Order->setPaymentConfirmed(1);
        }
        $orderStatus = $main::Setup->getSetupParameter($payment_method . '_order_status');
    }

    # Form transaction comments#
    my $comments = &main::getComments($payment_method, $payment_name, %{$response_hash{'response'}});
    
    
    $Order->setMetaData({bemerkung => $comments, zahlung_transaktions_id => $response_hash{'response'}{'tid'}, zahlung_plugin => "novalnet", zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash(\%paymentInfos) });
    
    # Finalize the order#
    $Order->finalize();

    # Set order status#
    $Order->setProcessingStatus($orderStatus);
    
    return ('bestellung_schritt_6_standalone', 'bestellung', {access_hash => $Order->getAccessHash()});
}

1;
