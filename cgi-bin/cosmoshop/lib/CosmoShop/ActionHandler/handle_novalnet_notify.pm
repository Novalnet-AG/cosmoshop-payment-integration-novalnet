### CosmoShop Novalnet Package
### $Author: Novalnet $
### $Date: 2019-04-09 $

package CosmoShop::ActionHandler::handle_novalnet_notify;
use base CosmoShop::Object::Base;
use strict;
use Socket;
use DateTime;
use Encode qw(decode encode);

my @payments = (
    'CREDITCARD',
    'INVOICE_START',
    'DIRECT_DEBIT_SEPA',
    'GUARANTEED_INVOICE',
    'GUARANTEED_DIRECT_DEBIT_SEPA',
    'PAYPAL',
    'PRZELEWY24',
    'ONLINE_TRANSFER',
    'IDEAL',
    'GIROPAY',
    'EPS',
    'TRANSACTION_CANCELLATION',
);

my @refunds = (
    'CREDITCARD_BOOKBACK',
    'PAYPAL_BOOKBACK',
    'REFUND_BY_BANK_TRANSFER_EU',
    'PRZELEWY24_REFUND',
    'GUARANTEED_SEPA_BOOKBACK',
    'GUARANTEED_INVOICE_BOOKBACK',
    'CASHPAYMENT_REFUND',
);

my @chargebacks = (
    'RETURN_DEBIT_SEPA',
    'REVERSAL',
    'CREDITCARD_CHARGEBACK',
);


my @collections = (
    'INVOICE_CREDIT',
    'CREDIT_ENTRY_CREDITCARD',
    'CREDIT_ENTRY_SEPA',
    'DEBT_COLLECTION_SEPA',
    'DEBT_COLLECTION_CREDITCARD',
    'ONLINE_TRANSFER_CREDIT',
    'CASHPAYMENT_CREDIT',
    'CREDIT_ENTRY_DE',
    'DEBT_COLLECTION_DE',
);

my %paymentGroups = (
    'novalnet_cc'          => ['CREDITCARD', 'CREDITCARD_BOOKBACK', 'CREDITCARD_CHARGEBACK', 'CREDIT_ENTRY_CREDITCARD', 'DEBT_COLLECTION_CREDITCARD'],
    'novalnet_sepa'        => ['DIRECT_DEBIT_SEPA', 'GUARANTEED_SEPA_BOOKBACK', 'RETURN_DEBIT_SEPA', 'DEBT_COLLECTION_SEPA', 'CREDIT_ENTRY_SEPA', 'REFUND_BY_BANK_TRANSFER_EU', 'GUARANTEED_DIRECT_DEBIT_SEPA'],
    'novalnet_ideal'       => ['IDEAL', 'REFUND_BY_BANK_TRANSFER_EU', 'ONLINE_TRANSFER_CREDIT', 'REVERSAL', 'CREDIT_ENTRY_DE','DEBT_COLLECTION_DE'],
    'novalnet_instantbank' => ['ONLINE_TRANSFER', 'REFUND_BY_BANK_TRANSFER_EU', 'ONLINE_TRANSFER_CREDIT', 'REVERSAL', 'CREDIT_ENTRY_DE','DEBT_COLLECTION_DE'],
    'novalnet_eps'         => ['EPS', 'ONLINE_TRANSFER_CREDIT', 'REFUND_BY_BANK_TRANSFER_EU', 'REVERSAL', 'CREDIT_ENTRY_DE','DEBT_COLLECTION_DE'],
    'novalnet_paypal'      => ['PAYPAL', 'PAYPAL_BOOKBACK'],
    'novalnet_przelewy24'  => ['PRZELEWY24','PRZELEWY24_REFUND'],
    'novalnet_giropay'     => ['GIROPAY', 'ONLINE_TRANSFER_CREDIT', 'REFUND_BY_BANK_TRANSFER_EU', 'REVERSAL', 'CREDIT_ENTRY_DE','DEBT_COLLECTION_DE'],
    'novalnet_prepayment'  => ['INVOICE_START', 'INVOICE_CREDIT', 'REFUND_BY_BANK_TRANSFER_EU'],
    'novalnet_invoice'     => ['INVOICE_START', 'INVOICE_CREDIT', 'GUARANTEED_INVOICE', 'REFUND_BY_BANK_TRANSFER_EU', 'GUARANTEED_INVOICE_BOOKBACK', 'CREDIT_ENTRY_DE','DEBT_COLLECTION_DE'],
    'novalnet_cashpayment'  => ['CASHPAYMENT', 'CASHPAYMENT_CREDIT', 'CASHPAYMENT_REFUND']
);

my @requiredParams = ('vendor_id', 'tid', 'payment_type', 'status', 'tid_status');

my $timeStamp = '';
my $timeStampDate = '';
my $timeStampTime = '';


my $message = '';
my $serverRequest = {};
my $orderReference = {};

#/////////////////////////////////////////////////////////////////////////////

=head2 handle
    Parameters  : none
    Returns     : string
    Description : Action handler for Novalnet callback.
=cut

sub handle {
    my $self = shift;

    my $Response = $main::CosmoShop->getResponse();
	
    return ('shopstart', 'shop', {}) unless ($main::Setup->pluginActive('novalnet'));
    my $authenticationMessage = $self->handleAuthentication();
    if($authenticationMessage) {
        $Response->set_content($authenticationMessage);
        return ('dummy');
    }

    $serverRequest = $self->validateServerRequest();
    
    if($message) {
        $Response->set_content("message=$message");
        return ('dummy');
    }

    my $currentDate = DateTime->now();
    $timeStamp = $currentDate->ymd('.') . ' ' . $currentDate->hms(':');
    $timeStampDate = $currentDate->ymd('.');
    $timeStampTime =  $currentDate->hms(':');

    my ($orderNo, $usage, $transactionDetails) = $self->getOrderReference();
    
    if($message) {
        $Response->set_content("message=$message");
        return ('dummy');
    }
    my $orderStatus = '';
    
    my $serverAmount = ($serverRequest->{amount}/100) .' '. $serverRequest->{currency};
    if ($serverRequest->{callback_type} eq 'CANCELLATION' && $transactionDetails->{tid_status} =~ /^(?:75|85|91|98|99|100)$/o ) {
		$message = &main::getTranslatText('info_novalnet_cancelled_tid_text');
        $message =~ s/\%timeStampDate\%/$timeStampDate/sig;
        $message =~ s/\%timeStampTime\%/$timeStampTime/sig;
        $transactionDetails->{tid_status} = $serverRequest->{tid_status};
        $orderReference->setMetaData({
            bemerkung      => decode('utf-8', $orderReference->getMainData()->{bemerkung}) . '<br><br>' . decode('utf-8', $message),
            zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash($transactionDetails)
        });
        $orderReference->setProcessingStatus('3');
        $orderReference->finalize();
        $self->sendNotificationMail($message);
    } elsif ($serverRequest->{callback_type} eq 'INITIAL') {
        if($transactionDetails->{tid_status} && $transactionDetails->{tid_status} =~ /^(?:75|86|90|85|91|98|99)$/o ) {
            if($serverRequest->{tid_status} eq '100') {
            $message = &main::getTranslatText('info_novalnet_confirm_message_text');
            $message =~ s/\%timeStampDate\%/$timeStampDate/sig;
            $message =~ s/\%timeStampTime\%/$timeStampTime/sig;
            
            if(inArray( $serverRequest->{payment_type}, ('GUARANTEED_INVOICE', 'GUARANTEED_DIRECT_DEBIT_SEPA','INVOICE_START') ) )
            {
				# Form transaction comments#
				my $comments = &main::getComments($usage, $orderReference->getPaymentName(), %{$serverRequest});
				$message = $message .'<br><br>'. $comments;
				$message =~ s/<br>/\n/g;
			}
                $orderStatus = $main::Setup->getSetupParameter($usage . '_order_status');
                if($serverRequest->{payment_type} ne 'INVOICE_START') {
                    $transactionDetails->{paid_amount} += $serverRequest->{amount};
                    if($serverRequest->{payment_type} eq 'GUARANTEED_INVOICE') {
                        $orderStatus = $main::Setup->getSetupParameter($usage . '_callback_status');
                    }
                    $orderReference->setPaymentConfirmed(1);
                    $orderReference->finalize();
                }
            } elsif($transactionDetails->{tid_status} =~ /^(?:75|86|90)$/o && $serverRequest->{tid_status} =~ /^(?:85|91|98|99)$/o)  {
                $message = &main::getTranslatText('info_novalnet_pending_message_text');
                $message =~ s/\%shoptid\%/$serverRequest->{shop_tid}/sig;
                $message =~ s/\%timeStampDate\%/$timeStampDate/sig;
                $message =~ s/\%timeStampTime\%/$timeStampTime/sig;
                $orderStatus = $main::Setup->getSetupParameter('novalnet_onhold_order_complete');
            }

            $transactionDetails->{tid_status} = $serverRequest->{tid_status};
            $orderReference->setProcessingStatus($orderStatus);
            
            if(inArray( $serverRequest->{payment_type}, ('GUARANTEED_INVOICE', 'GUARANTEED_DIRECT_DEBIT_SEPA') ) && $serverRequest->{tid_status} eq '100') {
				$orderReference->setMetaData({
					bemerkung      => decode('utf-8', $message),
					zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash($transactionDetails)
				});
				sendGuaranteeMail();
			}else{
				
				$orderReference->setMetaData({
					bemerkung      => decode('utf-8', $orderReference->getMainData()->{bemerkung}) . '<br><br>' .decode('utf-8', $message),
					zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash($transactionDetails)
				});
			}
            $self->sendNotificationMail($message);
        } else {
            $message = 'Novalnet callback script executed already.';
        }
    } elsif($serverRequest->{callback_type} =~ /^(?:REFUND|CHARGEBACK)$/o) {
        if($serverRequest->{callback_type} eq 'REFUND') {
            $message = &main::getTranslatText('info_novalnet_bookback_message_text');
        } else {
            $message = &main::getTranslatText('info_novalnet_chargeback_message_text');
        }
        $message =~ s/\%shoptid\%/$serverRequest->{shop_tid}/sig;
        $message =~ s/\%amount\%/$serverAmount/sig;
        $message =~ s/\%timestamp\%/$timeStamp/sig;
        $message .= &main::getTranslatText('info_novalnet_subsequent_tid_text');
        $message =~ s/\%tid\%/$serverRequest->{tid}/sig;

        $orderReference->setMetaData({
            bemerkung     => decode('utf-8', $orderReference->getMainData()->{bemerkung}) . '<br><br>' .decode('utf-8', $message),
            zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash($transactionDetails)
        });
        $self->sendNotificationMail($message);
    } elsif($serverRequest->{callback_type} eq 'CREDIT') {
		
		if( !inArray( $serverRequest->{payment_type}, ('INVOICE_CREDIT', 'CASHPAYMENT_CREDIT', 'ONLINE_TRANSFER_CREDIT') ) )
		{
			$message = &main::getTranslatText('info_novalnet_callback_message_text');
			$message =~ s/\%shoptid\%/$serverRequest->{shop_tid}/sig;
			$message =~ s/\%amount\%/$serverAmount/sig;
			$message =~ s/\%timestamp\%/$timeStamp/sig;
			$message .= &main::getTranslatText('info_novalnet_paid_tid_text');
			$message =~ s/\%tid\%/$serverRequest->{tid}/sig;
			
            $orderReference->setMetaData({
                bemerkung      => decode('utf-8', $orderReference->getMainData()->{bemerkung}). '<br><br>' .decode('utf-8', $message),
                zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash($transactionDetails)
            });
            $orderReference->setPaymentConfirmed(1);
            $orderReference->finalize();
            $self->sendNotificationMail($message);
            
		}elsif($transactionDetails->{paid_amount} lt $transactionDetails->{transaction_amount} && inArray( $serverRequest->{payment_type}, ('INVOICE_CREDIT', 'CASHPAYMENT_CREDIT', 'ONLINE_TRANSFER_CREDIT'))) {
            $transactionDetails->{paid_amount} += $serverRequest->{amount};
			$message = &main::getTranslatText('info_novalnet_callback_message_text');
			$message =~ s/\%shoptid\%/$serverRequest->{shop_tid}/sig;
			$message =~ s/\%amount\%/$serverAmount/sig;
			$message =~ s/\%timestamp\%/$timeStamp/sig;
			$message .= &main::getTranslatText('info_novalnet_paid_tid_text');
			$message =~ s/\%tid\%/$serverRequest->{tid}/sig;
			
            my $orderStatus = $main::Setup->getSetupParameter($usage . '_order_status');
            if($usage =~ /^novalnet_(?:invoice|prepayment|cashpayment)$/i && $transactionDetails->{paid_amount} ge $transactionDetails->{transaction_amount}) {
                $orderStatus = $main::Setup->getSetupParameter($usage . '_callback_status');
            }
            $orderReference->setMetaData({
                bemerkung      => decode('utf-8', $orderReference->getMainData()->{bemerkung}). '<br><br>' .decode('utf-8', $message),
                zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash($transactionDetails)
            });
            $orderReference->setPaymentConfirmed(1);
            $orderReference->setProcessingStatus($orderStatus);
            $orderReference->finalize();
            $self->sendNotificationMail($message);
        } else {
            $message = 'Novalnet callback received. Callback Script executed already. Refer Order :'.$serverRequest->{"order_no"};
        }
    } else {
            $message = 'Payment type '. $serverRequest->{"payment_type"}.' is mismatched!';
    }

    if($message) {
        $message = decode('utf-8', $message);
        $Response->set_content("message=$message");
    }
    return ('dummy');
}

#/////////////////////////////////////////////////////////////////////////////

=head2 handleAuthentication
    Parameters  : none
    Returns     : string
    Description : Validate the host ip
=cut

sub handleAuthentication {
    my $self = shift;

    my ($hostIp) = inet_ntoa((gethostbyname("pay-nn.de"))[4]);

    if(!$hostIp) {
        return 'Novalnet HOST IP missing.';
    } elsif(!$main::Setup->novalnet_callback_test_mode) {
        my $remoteIp = $ENV{HTTP_CLIENT_IP} || $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};
        if( $remoteIp ne $hostIp) {
            return 'Unauthorised access from the IP [' . $remoteIp . ']';
        }
    }
}

#/////////////////////////////////////////////////////////////////////////////

=head2 validateServerRequest
    Parameters  : none
    Returns     : hash
    Description : Validate the server request parameters
=cut

sub validateServerRequest {
    my $self = shift;
    my $Request = $main::CosmoShop->getRequest();
    my %parameters = %{$Request->getParameter()};

    if ($parameters{payment_type} eq 'TRANSACTION_CANCELLATION' || $parameters{tid_status} > '100'){
        $parameters{shop_tid} = $parameters{tid};
        $parameters{callback_type} = 'CANCELLATION';
    } elsif ( inArray( $parameters{payment_type}, @refunds ) ){ # Set flag for refund transaction
        $parameters{shop_tid} = $parameters{tid_payment};
        $parameters{callback_type} = 'REFUND';
        $parameters{placeholder} = 'Refund/Bookback';
        push (@requiredParams, 'tid_payment');
    } elsif ( inArray( $parameters{payment_type}, @chargebacks ) ){ # Set flag for Chargeback transaction
        $parameters{shop_tid} = $parameters{tid_payment};
        $parameters{callback_type} = 'CHARGEBACK';
        $parameters{placeholder} = 'Chargeback';
        push (@requiredParams, 'tid_payment');
    } elsif ( inArray( $parameters{payment_type}, @collections ) ){ # Set flag for Credit transaction
        $parameters{shop_tid} = $parameters{tid_payment};
        $parameters{callback_type} = 'CREDIT';
        push (@requiredParams, 'tid_payment');
    } elsif ( inArray( $parameters{payment_type}, @payments ) ){ # Set flag for Initial transaction
        $parameters{shop_tid} = $parameters{tid};
        $parameters{callback_type} = 'INITIAL';
    }

    # Check for Valid payment type
    if(!$parameters{callback_type}) {
        $message = 'The Payment type is invalid';
        return %parameters;
    }

    # Check for required parameters
    foreach my $key (@requiredParams) {
        if (!$parameters{$key} ) {
            $message = "Required Param $key Missing.";
            last;
        } elsif($key =~ /^(tid|tid_payment|signup_tid|shop_tid)$/ && $parameters{$key} !~ /^\d{17}$/) {
            $message = "Invalid TID";
        }
    }
    return \%parameters
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getOrderReference
    Parameters  : none
    Returns     : string
    Description : Get the order value for your reference
=cut

sub getOrderReference {
    my $self = shift;

    # Get the order No. from the shop order table based on the received data
    my $tableOrders = $main::Setup->getDbTable('auftraege');
    my ($orderNoQuery, $usage, $orderNo) = ('')x3;
    my $sql = "SELECT auftragsnr FROM $tableOrders WHERE zahlung_transaktions_id = ?";
	
    if($serverRequest->{"order_no"}) {
        $sql .= ' AND auftragsnr = ?';
        $orderNoQuery = $main::dbh->prepare($sql) or $self->_dbDie($sql);
        $orderNoQuery->execute($serverRequest->{"shop_tid"}, $serverRequest->{"order_no"});
    } else {
        $orderNoQuery = $main::dbh->prepare($sql) or $self->_dbDie($sql);
        $orderNoQuery->execute($serverRequest->{"shop_tid"});
    }
    $orderNo = $orderNoQuery->fetchrow_array();
	
    # Check whether the order No. is exist in the shop or not
    if(!$orderNo && $serverRequest->{"order_no"}) {
		require CosmoShop::Orders::Order;
		$orderReference = CosmoShop::Orders::Order->new({auftragsnr => $serverRequest->{"order_no"}});

        # Handle Communication failure
        if($orderReference) {
            my $usage = $orderReference->getPaymentUsage();

            if ($orderReference->isFinalized()) {
               $message = 'Novalnet callback received. Order no is not valid';
            }
            elsif( $paymentGroups{$usage} && inArray( $serverRequest->{payment_type}, @{$paymentGroups{$usage}} ) ) {
				
				my $orderStatus = '';
				my %paymentInfos = ();
				
				$paymentInfos{'transaction_amount'} = sprintf("%.02f", $orderReference->getOrderTotalGross()) * 100;
				$paymentInfos{'tid_status'}         = $serverRequest->{tid_status};
				
				if($serverRequest->{tid_status} eq '100') {
					$paymentInfos{'paid_amount'} = $paymentInfos{'transaction_amount'};
					$orderStatus = $main::Setup->getSetupParameter($usage . '_order_status');
				} else {
					$paymentInfos{'paid_amount'} = '0';
					$orderStatus = $main::Setup->getSetupParameter('novalnet_onhold_order_cancelled');
				}
				
				# Form transaction comments#
				my $comments = ( $serverRequest->{test_mode} == 1 ) ? &main::getTranslatText('novalnet_test_mode') . '<br>' : '';
				$comments   .= &main::getTranslatText('novalnet_tid') . ' : ' . $serverRequest->{tid} .'<br>';
				
                $orderReference->setMetaData({bemerkung => decode('utf-8', $comments), zahlung_transaktions_id => $serverRequest->{tid}, zahlung_plugin => "novalnet", zahlungsinfos => $main::CosmoShop->getObject('Utils::Checkout')->composeOrderPaymentInfosFromHash(\%paymentInfos) });
    
				# Finalize the order#
				$orderReference->finalize();

				# Set order status#
				$orderReference->setProcessingStatus($orderStatus);
				
				my $orderAmount = ($serverRequest->{amount}/100) .' '. $serverRequest->{currency};
				$message = &main::getTranslatText('info_novalnet_communication_break');
				$message =~ s/\%shoptid\%/$serverRequest->{shop_tid}/sig;
				$message =~ s/\%amount\%/$orderAmount/sig;
				$message =~ s/\%timestamp\%/$timeStamp/sig;
                return ('', '',{});
            } else {
                $message = 'Order Mapping failed';
            }
        }

        return ('', '',{});
    } elsif (!$orderNo) {
        $message = 'Order Mapping failed';
        return ('', '',{});
    }

    # Get all the order details
    require CosmoShop::Orders::Order;
    $orderReference = CosmoShop::Orders::Order->new({auftragsnr => $orderNo});
	
    # Get Payment type
    my $usage = $orderReference->getPaymentUsage();

    # Check for the appropriate payment type
    if($serverRequest->{callback_type} ne 'CANCELLATION' && (!$paymentGroups{$usage} || ! inArray( $serverRequest->{payment_type}, @{$paymentGroups{$usage}} ) ) ) {
        $message = "The payment type ($serverRequest->{payment_type}) mismatch with the payment $usage";
        return ('', '',{});
    }

    # Return the required values
    return ($orderNo, $usage, $orderReference->getPaymentInfos());
}

#/////////////////////////////////////////////////////////////////////////////

=head2 sendNotificationMail
    Parameters  : $message
    Returns     : string
    Description : Function to send callback mails
=cut

sub sendNotificationMail {
    my $self = shift;
    my ($message) = @_;

    if($main::Setup->novalnet_callback_mail_send && &main::validate_email($main::Setup->novalnet_callback_mail_to)) {
        &main::send_mail(
            $main::Setup->novalnet_callback_mail_to,#mailto
            '',
            'Novalnet Callback Script Access Report',#subject
            qq~$message~ #text
		);	
		return 'Mail sent : <br>' .$message;
    }
}

#/////////////////////////////////////////////////////////////////////////////

=head2 inArray
    Parameters  : $input
    Parameters  : @arrayList
    Returns     : bool
    Description : Check for the value is present in the array or not
=cut

sub inArray {
    my ($input, @arrayList) = @_;

    my $arrayAsString = join( '|', @arrayList );
    if ($input =~ /^(?:$arrayAsString)$/) {
        return 1;
    }
    return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 sendGuaranteeMail
    Parameters  : null
    Returns     : bool
    Description : Send the order confirmation mail for guarantee
=cut

sub sendGuaranteeMail {
	
	my $rumpfdaten          = $orderReference->getMainData();
	my $Session     		= $main::CosmoShop->getSession();
	my $posten              = $orderReference->getItems();
	my $rechnungsadresse    = $orderReference->getInvoiceAddress();
    my $lieferadresse       = $orderReference->getDeliveryAddress();
    
    my $best_umstid = uc($rechnungsadresse->{umstid});
    $best_umstid =~ s/\W//sig;
    my $shop_umstid = uc($main::Setup->getSetupParameter('shop_umstid'));
    $shop_umstid =~ s/\W//sig;
    
	my ($versandkosten_netto, $versandkosten_mwst)      = $orderReference->getShipmentCost();
    my ($zahlungskosten_netto, $zahlungskosten_mwst)    = $orderReference->getPaymentCost();
    
    my @posten = ();
    my $anzahl_posten = 0;
    my $anzahl_artikel = 0;
    my $i = 1;
    my %mwst_betraege = "";
    my $zahlungsbetrag = 0;
    my ($zahlart, $versandart, $zahlart_name, $versandart_name, $zahlart_kennung, $versandart_kennung);
    
    my @jetzt           = localtime(time);
    my $datum_str       = sprintf("%02d.%02d.%04d - %02d:%02d:%02d", $jetzt[3], $jetzt[4] + 1, $jetzt[5] + 1900, $jetzt[2], $jetzt[1], $jetzt[0]);
    
    
    my $gutschein_netto = 0;
    my $gutschein_mwst = 0;
    my $gutschein_name = "";
    my $gutschein_code = "";
    
    foreach my $row (@$posten) {
        next if ($row->{posten_sort} < 1000); # nur Gutscheine
        $gutschein_netto += $row->{posten_einzel_netto};
        $gutschein_mwst += $row->{posten_einzel_mwst};
        $gutschein_name = $row->{posten_name}." ".$row->{posten_artnum};
        $gutschein_code = $row->{posten_artnum};
    }

    #Änderungen durch Hagen Drees (2017-01-30); 10231
    my $einzel_netto_ = 0; my $einzel_mwst_  = 0;
    my $gesamt_netto_ = 0; my $gesamt_mwst_  = 0;

    foreach my $row (reverse @$posten) {
        if ($row->{posten_referenz} =~ m|^type:subarticle|) {
            $einzel_netto_ += $row->{posten_einzel_netto}; $einzel_mwst_  += $row->{posten_einzel_mwst}; 
            $gesamt_netto_ += $row->{posten_gesamt_netto}; $gesamt_mwst_  += $row->{posten_gesamt_mwst}; 
        } else {
            if (($row->{posten_einzel_netto} == 0) && ($row->{posten_gesamt_netto} == 0)) {
                $row->{posten_einzel_netto} = $einzel_netto_;  $row->{posten_einzel_mwst} = $einzel_mwst_;
                $row->{posten_gesamt_netto} = $gesamt_netto_;  $row->{posten_gesamt_mwst} = $gesamt_mwst_;
            } # if

            $einzel_netto_ = 0; $einzel_mwst_  = 0;
            $gesamt_netto_ = 0; $gesamt_mwst_  = 0;
        } # else
    } # foreach
    
    my $netto_warenwert = 0;
    foreach my $row (@$posten) {
        $mwst_betraege{$row->{posten_mwst_satz}} += $row->{posten_gesamt_mwst};
        my $einzelpreis = ($rumpfdaten->{preisdarstellung} eq "brutto") ? $row->{posten_einzel_netto} + $row->{posten_einzel_mwst} : $row->{posten_einzel_netto};
        my $gesamtpreis = ($rumpfdaten->{preisdarstellung} eq "brutto") ? $row->{posten_gesamt_netto} + $row->{posten_gesamt_mwst} : $row->{posten_gesamt_netto};
        $zahlungsbetrag += $gesamtpreis;
        
        if ($row->{posten_artnum_hauptartikel} eq "zahlung") {
            $zahlart = $row->{posten_artnum};
            $zahlart_name = $row->{posten_name};
            $zahlart_kennung = $row->{posten_namenszusatz};
        }
        
        if ($row->{posten_artnum_hauptartikel} eq "versand") {
            $versandart = $row->{posten_artnum};
            $versandart_name = $row->{posten_name};
            $versandart_kennung = $row->{posten_namenszusatz};
        }

        #Änderungen durch Hagen Drees (2017-01-30); 10231
        next if ($row->{posten_referenz} =~ m|^type:subarticle|); # Unter-Artikel ignorieren

        next if ($row->{posten_sort} == 0); # zahlung und versand hier ignorieren
        next if ($row->{posten_sort} >= 1000); # Gutscheine separat am Ende
        
        unless ($main::Setup->pluginActive('gutschein') && ($row->{posten_artnum_hauptartikel} eq "gutschein")) {
            $anzahl_posten ++;
            $anzahl_artikel += $row->{posten_menge};
            $netto_warenwert += $row->{posten_gesamt_netto};
        }
        
        my $str_zusatz = $row->{posten_namenszusatz};
        $str_zusatz =~ s/\|\:\|/<br>/sig;
        
        my %this_posten = (
            i               => $i,
            link            => $Session->makeLink({action => "showdetail", artnum => $row->{posten_artnum_hauptartikel}, no_session => 1, }),
            menge           => $row->{posten_menge},
            artikelnummer   => $row->{posten_artnum},
            artikelname     => $row->{posten_name},
            variantenzusatz => $str_zusatz,
            einzelpreis     => $main::Preise->preisFormat({preis => $einzelpreis}),
            gesamtpreis     => $main::Preise->preisFormat({preis => $gesamtpreis}),
            vpe             => ($row->{posten_vpe} > 1) ? $row->{posten_vpe} : "",
            lieferzeit      => $row->{lieferzeit_text} || "",
            referenz        => $row->{posten_referenz}, # for hooks use
            SUBARTICLE      => ($row->{posten_referenz} =~ /type:bundlecomponent/) ? 1 : 0,
        );
        
        #Einheiten
        if($main::Setup->pluginActive('einheiten') && $row->{posten_einheit} ne ''){
            $this_posten{EINHEIT_ANZEIGEN} = 1;
            $this_posten{inhalt}  = &main::format_float($row->{posten_inhalt});
            $this_posten{einheit} = $row->{posten_einheit};
            
            my $grundpreis = ($rumpfdaten->{preisdarstellung} eq "brutto") ? 
               &CosmoShop::Preise::Preise_bruttoFromNetto($row->{posten_grundpreis},$row->{posten_mwst_satz}) 
               : 
               $row->{posten_grundpreis};
            
            if($grundpreis>0){
                $this_posten{GRUNDPREIS_ANZEIGEN} = 1;
                $this_posten{grundpreis} = $main::Preise->preisFormat({preis => $grundpreis}),
                $this_posten{grundeinheit} = $row->{posten_grundeinheit};
            } 
        }       

        #Änderungen durch Hagen Drees (2017-01-13); 10231
        if ($main::CosmoShop->Plugins->active('ticket')) {
           $this_posten{ticket_details} = $main::CosmoShop->Plugins->ticket->getTemplateTicketDetailsBestellmail($row->{posten_ticket_template}) if ($row->{posten_ticket});
           if ($row->{posten_ticket_postversand} && $row->{posten_ticketids} ne ""){
           		my @ticketids = split(/\,/,$row->{posten_ticketids});
           		my @ticketids_hash;
           		foreach my $ticket (@ticketids){
	           		if($main::CosmoShop->Plugins->ticket->isTicketFromTicketPool($ticket)){
	           			my %ticket_hash = (
	           				ticketid => $ticket,
	           			);
	           			push(@ticketids_hash,\%ticket_hash);
           			}
           		}
           		$this_posten{ticketids} = \@ticketids_hash;
           }
        } # if        

        push @posten, \%this_posten;
        $i ++;
    }
    
    if ($gutschein_name ne '') {
        my $wert = ($rumpfdaten->{preisdarstellung} eq "brutto") ? $gutschein_netto + $gutschein_mwst : $gutschein_netto;
        $netto_warenwert += $gutschein_netto;
        
        my %this_posten = (
            i               => $i,
            menge           => 1,
            artikelnummer   => "gutschein",
            artikelname     => $gutschein_name,
            variantenzusatz => $gutschein_code,
            einzelpreis     => $main::Preise->preisFormat({preis => $wert}),
            gesamtpreis     => $main::Preise->preisFormat({preis => $wert}),
            vorschaubild    => "s/b.gif",
        );
        
        push @posten, \%this_posten;
    }
    
    my @mwst_liste = ();
    
    foreach my $prozent (keys %mwst_betraege) {
        my $betrag = $mwst_betraege{$prozent};
        my $prozent_form = $prozent;
        
        $prozent_form =~ s/\./\,/sig;
        $prozent_form =~ s/\,00//sig;
        $prozent_form =~ s/0$//sig;
        
        next if ($rumpfdaten->{mwst_typ} ne "normal");
        next if (($prozent == 0) || ($betrag == 0));
        
        my %this_mwst = (
            mwst        => $main::Preise->preisFormat({preis => $betrag}),
            mwst_satz   => $prozent."%",
        );
        
        push @mwst_liste, \%this_mwst;
    }
    
    my $versandkosten   = ($rumpfdaten->{preisdarstellung} eq "brutto") ? $versandkosten_netto + $versandkosten_mwst : $versandkosten_netto;
    my $zahlungskosten  = ($rumpfdaten->{preisdarstellung} eq "brutto") ? $zahlungskosten_netto + $zahlungskosten_mwst : $zahlungskosten_netto;
    my $zahlungsbetrag  = $rumpfdaten->{gesamt_netto} + $rumpfdaten->{gesamt_mwst};
	
	my %Platzhalter = (
        netto_warenwert         => $main::Preise->preisFormat({preis => $netto_warenwert}),
        bestelldatum            => $datum_str,
        anzeigen_umstid_hinweis => (($best_umstid ne "") && ($shop_umstid ne "") && (substr($best_umstid, 0, 2) ne substr($shop_umstid, 0, 2))),
        umstid_konvertiert      => $best_umstid,
        baseurl                 => $main::CosmoShop->getObject('Structure')->getUserHtmlDir({asUrl => 1, subDir => 'pix'}).'/',
        auftragsnummer          => $serverRequest->{order_no},
        bemerkung          		=> $rumpfdaten->{bemerkung} || '',
        versandkosten           => $main::Preise->preisFormat({preis => $versandkosten}),
        zahlungskosten          => ($zahlungskosten) ? $main::Preise->preisFormat({preis => $zahlungskosten}) : "",
        versandart              => $versandart_name,
        zahlungsart             => $zahlart_name,
        transaction_id          => $rumpfdaten->{zahlung_transaktions_id},
        BRUTTO                  => ($rumpfdaten->{preisdarstellung} eq 'brutto'),
        gesamt                  => $main::Preise->preisFormat({preis => $zahlungsbetrag}),
        MWST_BEFREIT            => ($rumpfdaten->{mwst_typ} ne "normal"),
        anzahl_posten           => $anzahl_posten,
        anzahl_artikel          => $anzahl_artikel,
        POSTEN                  => \@posten,
        NETTO_EU                => ($rumpfdaten->{mwst_typ} eq "ustid-befreit"),
        NETTO_NON_EU            => ($rumpfdaten->{mwst_typ} eq "non-eu"),
        kunden_id               => $rumpfdaten->{kunden_id},
        MWST_LISTE              => \@mwst_liste,
        );
    
    $Platzhalter{"best_".$_} = $rechnungsadresse->{$_} foreach keys %$rechnungsadresse;
    $Platzhalter{"lief_".$_} = $lieferadresse->{$_} foreach keys %$lieferadresse;
    $Platzhalter{lief_abweichend} = 1 if ($orderReference->hasShippingAddress());
	
	my $mailto_shopbetreiber = $main::Setup->getSetupParameter('shop_bestellempfaenger') || $main::shopbetreiber;
	
	my $TemplateEngine = $main::CosmoShop->getTemplateEngine();
    my $mailbody_kunde = $TemplateEngine->render({type => "mail", object => 'novalnet_mail', template => "bestellmail_kunde", params => {Platzhalter => \%Platzhalter}});
    
    my $subject;
    if ($mailbody_kunde =~ s/\<subject\>(.*?)\<\/subject\>//sig) { # Subject im extra HTML-Tag
        $subject = $1;
    } elsif ($mailbody_kunde =~ s/^Subject\:(.*?)\r*\n//si) { # Subject in der ersten Zeile
        $subject = $1;
    }
    if($serverRequest->{email} ne '')
    {
		&main::send_mime_mail( $serverRequest->{email}, $main::shopbetreiber,$subject, $mailbody_kunde, ());
	}
}
1;
