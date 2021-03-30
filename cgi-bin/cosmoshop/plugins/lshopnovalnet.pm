use strict;
use String::CRC32;
use MIME::Base64;
use Switch;
use POSIX qw(strftime);
use DateTime;
use Digest::MD5 qw(md5_base64);
use Digest::SHA qw(sha256_hex);
use Crypt::CBC;
use Crypt::Rijndael;

#/////////////////////////////////////////////////////////////////////////////

=head2 getMerchantDetails
    Parameters  : shift
    Returns     : bool / hash
    Description : To get the merchant details form shop back-end
=cut

sub getMerchantDetails {
    my $params = shift;
    my %merchant_datas = (
        'vendor'             => 'novalnet_vendor_id',
        'product'            => 'novalnet_product_id',
        'tariff'             => 'novalnet_tariff_id',
        'auth_code'          => 'novalnet_auth_code',
        'payment_access_key' => 'novalnet_access_key'
    );
    while( my( $key, $value ) = each %merchant_datas ){
        return 'invalidMarchantDetails' if ($main::Setup->getSetupParameter($value) eq '');
        $params->{$key} = $main::Setup->getSetupParameter($value);
    }
    return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getRequestUrl
    Parameters  : shift
    Returns     : string
    Description : To get the Novalnet request URLs
=cut

sub getRequestUrl {
    my $method = shift;
    my %payment_urls = (
        'novalnet_cc'          => 'https://payport.novalnet.de/pci_payport',
        'novalnet_paypal'      => 'https://payport.novalnet.de/paypal_payport',
        'novalnet_ideal'       => 'https://payport.novalnet.de/online_transfer_payport',
        'novalnet_przelewy24'  => 'https://payport.novalnet.de/globalbank_transfer',
        'novalnet_instantbank' => 'https://payport.novalnet.de/online_transfer_payport',
        'novalnet_eps'         => 'https://payport.novalnet.de/giropay',
        'novalnet_giropay'     => 'https://payport.novalnet.de/giropay'
    );
    return $payment_urls{$method};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getRequestParams
    Parameters  : none
    Returns     : hash
    Description : To build request param for transaction call
=cut

sub getRequestParams {
    my %params;
    &main::getMerchantDetails(\%params);

    my $Response         = $main::CosmoShop->getResponse();
    my $Session          = $main::CosmoShop->getSession();
    my $Order            = $main::CosmoShop->getOrder();

    my $Request          = $main::CosmoShop->getRequest();
    my $in               = $Request->getParameter();

    my $order_data       = $Order->getMainData();
    my $billing_address  = $Order->getInvoiceAddress();
    my $delivery_address = $Order->getDeliveryAddress();

    my $payment_method   = $Order->getPaymentUsage();
    my $payment_name     = $Order->getPaymentName();

    my $OrderNr = $Order->getOrSetOrderNr();
    my $amount = sprintf("%.02f", $Order->getOrderTotalGross()) * 100;
    my $ip_addr = $ENV{HTTP_CLIENT_IP} || $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};
    my $payment_data = &main::getPaymentInfo();
    my %request_params = (
        'key'                => $payment_data->{$payment_method}{'key'},
        'payment_type'       => $payment_data->{$payment_method}{'payment_type'},
        'test_mode'			 => $main::Setup->getSetupParameter($payment_method.'_test_mode'),
        'currency'           => $order_data->{currency},
        'first_name'         => $billing_address->{vorname},
        'last_name'          => $billing_address->{nachname} || $billing_address->{vorname},
        'gender'             => 'u',
        'email'              => $billing_address->{mail},
        'street'             => $billing_address->{strasse}.' '.$billing_address->{hausnr},
        'search_in_street'   => 1,
        'city'               => $billing_address->{ort},
        'zip'                => $billing_address->{plz},
        'lang'               => uc($order_data->{sprache}) || 'DE',
        'country_code'       => $billing_address->{land_iso2} || 'DE',
        'remote_ip'          => $ip_addr,
        'order_no'           => $OrderNr,
        'customer_no'        => $order_data->{kunden_id} || 'guest',
        'system_name'        => 'Cosmoshop',
        'system_version'     => $main::version . '-NN_2.0.1',
        'system_ip'          => $ENV{SERVER_ADDR},
        'system_url'         => $main::CosmoShop->getScriptUrl({ssl => 1,order_commit => 1}),
        'amount'             => $amount,
        'tel'                => $billing_address->{tel} || '',
    );

    %request_params = (%request_params, %params);
	
    if($main::Setup->getSetupParameter($payment_method.'_transaction_type') eq 'authorize') {
            my $on_hold_amount = $main::Setup->getSetupParameter($payment_method.'_manual_limit');
            if(!$on_hold_amount || ($amount >= $on_hold_amount)) {
                $request_params{'on_hold'} = 1;
            }
    }
    $request_params{'hook_url'} = $main::Setup->novalnet_notify_url if( $main::Setup->novalnet_notify_url ne '') ;
    $request_params{'notify_url'} = $main::Setup->novalnet_notify_url if( $main::Setup->novalnet_notify_url ne '') ;

    my @inv_pre = ('novalnet_prepayment', 'novalnet_invoice');
    my @redirect_payments = ('novalnet_paypal', 'novalnet_ideal', 'novalnet_instantbank', 'novalnet_eps', 'novalnet_giropay','novalnet_przelewy24');
	
	push (@redirect_payments, 'novalnet_cc') if ($main::Setup->novalnet_cc_3d || $main::Setup->novalnet_cc_force_redirect);
	
    switch ($payment_method) {
        case 'novalnet_invoice' {
            $request_params{'invoice_type'} = 'INVOICE';
            $request_params{'invoice_ref'}  = "BNR-" . $request_params{'product'} . "-" . $request_params{'order_no'};

            if ($main::Setup->novalnet_invoice_due_date ne '' && $main::Setup->novalnet_invoice_due_date >= 7) {
                my $dt = DateTime->now();
                $dt->add(days => $main::Setup->novalnet_invoice_due_date);
                $request_params{'due_date'} = $dt->ymd;
            }
        }
        case 'novalnet_prepayment' {
            $request_params{'invoice_type'} = 'PREPAYMENT';
            $request_params{'invoice_ref'}  = "BNR-" . $request_params{'product'} . "-" . $request_params{'order_no'};
        }

        case (\@redirect_payments) {
            my $return_url = $main::CosmoShop->getObject('Structure')->getUserHtmlDir({asUrl => 1, ssl => 1})."/novalnet/transaction_return.php?";
            my @Chars = ('1'..'9');
			my $Length = 16;
            $request_params{'input1'}             = 'access_hash';
            $request_params{'inputval1'}          = $Order->getAccessHash();
            $request_params{'input2'}             = 'action';
            $request_params{'inputval2'}          = 'handle_novalnet_payment';
            $request_params{'input3'}             = 'wkid';
            $request_params{'inputval3'}          = $in->{'wkid'};
            $request_params{'input4'}             = 'ls';
            $request_params{'inputval4'}          = $in->{'ls'};
            $request_params{'implementation'}     = 'ENC';
            $request_params{'return_url'}          = $return_url;
            $request_params{'return_method'}       = 'POST';
            $request_params{'error_return_url'}    = $return_url;
            $request_params{'error_return_method'} = 'POST';

			for (1..$Length) {
				$request_params{'uniqid'} .= $Chars[int rand @Chars];
			}

            &main::encodeParams(\%request_params);
            if ($payment_method eq 'novalnet_cc') {
                $request_params{'cc_3d'}            = 1 if ($main::Setup->novalnet_cc_3d);
                $request_params{'pan_hash'}  		= $in->{'novalnet_cc_hash'};
				$request_params{'unique_id'}  		= $in->{'novalnet_cc_uniqueid'};
            }
        }

        case 'novalnet_sepa' {
            $request_params{'bank_account_holder'}  = $in->{'novalnet_sepa_owner'};
            $request_params{'iban'}  = $in->{'nnsepa_iban'};
            
            if ($main::Setup->novalnet_sepa_due_date && $main::Setup->novalnet_sepa_due_date > 2 && $main::Setup->novalnet_sepa_due_date < 14) {
                my $sepaDueDate = DateTime->now();
                $sepaDueDate->add(days => $main::Setup->novalnet_sepa_due_date);
                $request_params{'sepa_due_date'} = $sepaDueDate->ymd;
            }
        }
        
        case 'novalnet_cc' {
			$request_params{'pan_hash'}  = $in->{'novalnet_cc_hash'};
            $request_params{'unique_id'}  = $in->{'novalnet_cc_uniqueid'};
		}
		
		case 'novalnet_cashpayment' {
			
            if ($main::Setup->novalnet_cashpayment_due_date ne '') {
                my $dt = DateTime->now();
                $dt->add(days => $main::Setup->novalnet_cashpayment_due_date);
                $request_params{'cp_due_date'} = $dt->ymd;
            }
        }
    }
    
    # Add Guarantee payment details.
    if($payment_method =~ /^novalnet_(?:invoice|sepa)$/o && $Session->getVar($payment_method . "_guarantee_payment") ) {
		if($in->{$payment_method . '_dob'}) {
			$request_params{'birth_date'} = $in->{$payment_method . '_dob'};
		}
        $payment_method .= '_guarantee';
    }
    
    $request_params{'key'}          = $payment_data->{$payment_method}{'key'};
    $request_params{'payment_type'} = $payment_data->{$payment_method}{'payment_type'};
	
    delete $request_params{'payment_access_key'};
    
    return %request_params;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getPaymentInfo
    Parameters  : payment
    Returns     : int
    Description : To get payment method key
=cut

sub getPaymentInfo {
    my $payment = shift;
    my %payment_keys = (
        'novalnet_prepayment'  => {
            'key' => 27,
            'payment_type' => 'INVOICE_START',
        },
        'novalnet_invoice'     => {
            'key' => 27,
            'payment_type' => 'INVOICE_START',
        },
        'novalnet_cc'          => {
            'key' => 6,
            'payment_type' => 'CREDITCARD',
        },
        'novalnet_sepa'        => {
            'key' => 37,
            'payment_type' => 'DIRECT_DEBIT_SEPA',
        },
        'novalnet_paypal'      => {
            'key' => 34,
            'payment_type' => 'PAYPAL',
        },
        'novalnet_ideal'       => {
            'key' => 49,
            'payment_type' => 'IDEAL',
        },
        'novalnet_instantbank' => {
            'key' => 33,
            'payment_type' => 'ONLINE_TRANSFER',
        },
        'novalnet_eps'         => {
            'key' => 50,
            'payment_type' => 'EPS',
        },
        'novalnet_giropay'     => {
            'key' => 69,
            'payment_type' => 'GIROPAY',
        },
        'novalnet_przelewy24'  => {
            'key' => 78,
            'payment_type' => 'PRZELEWY24',
        },
        'novalnet_cashpayment'  => {
            'key' => 59,
            'payment_type' => 'CASHPAYMENT',
        },
        'novalnet_invoice_guarantee'  => {
            'key' => 41,
            'payment_type' => 'GUARANTEED_INVOICE',
        },
        'novalnet_sepa_guarantee'  => {
            'key' => 40,
            'payment_type' => 'GUARANTEED_DIRECT_DEBIT_SEPA',
        },
    );

    return \%payment_keys;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 httpRequest
    Parameters  : hash
    Returns     : hash
    Description : To perform http request.
=cut

sub httpRequest {

    my ($url, %request_hash, $payment) = @_;
    use LWP::UserAgent;
    my $ua       = LWP::UserAgent->new();
    my $ua_response = $ua->post( $url, \%request_hash );

    my ($comments, $response_content, %response_hash, %http_response );

    my $error_message = '';

    if ($ua_response->is_success) {
        $response_content = $ua_response->content();
        %response_hash    = split /[&=]/, $response_content;
		$http_response{'response'} = \%response_hash ;
    }
    else {
        $http_response{'status'}   = $ua_response->status_line;
    }
    return %http_response;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 encodeParams
    Parameters  : hash
    Returns     : none
    Description : To encode the params
=cut

sub encodeParams {
    my $params = shift;
    my @encode_params = ('auth_code', 'product', 'tariff', 'amount', 'test_mode');
    
    foreach my $param (@encode_params) {
			my $cipher = Crypt::CBC->new(
			{
				'key'         => $main::Setup->novalnet_access_key,

				'iv'          => $params->{'uniqid'},
				
				'cipher'      => 'Crypt::Rijndael',

				'literal_key' => 1,

				 'header'      => 'none',

				keysize       => 256 / 8

			}

		);
		$params->{$param} =  encode_base64($cipher->encrypt($params->{$param}), "");
	}
    $params->{'hash'} = &main::createHash(\%$params);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 decodeParams
    Parameters  : hash
    Returns     : none
    Description : To decode the params
=cut

sub decodeParams {
    my $params = shift;
    my @decode_params = ('auth_code', 'product', 'tariff', 'amount', 'test_mode');
    
    foreach my $param (@decode_params) {
			my $cipher = Crypt::CBC->new(

			{
				'key'         => $main::Setup->novalnet_access_key,

				'iv'          => $params->{'uniqid'},
				
				'cipher'      => 'Crypt::Rijndael',

				'literal_key' => 1,

				 'header'      => 'none',

				keysize       => 256 / 8
			}

		);
		$params->{$param} = $cipher->decrypt(decode_base64($params->{$param}));
	}
    $params->{'hash2'} = &main::createHash(\%$params);
}


#/////////////////////////////////////////////////////////////////////////////

=head2 createHash
    Parameters  : hash
    Returns     : string
    Description : To create hash string
=cut

sub createHash {
    my $params = shift;
    my @encode_params = ('auth_code', 'product', 'tariff', 'amount', 'test_mode','uniqid');
    my $hash;
	
    foreach my $param (@encode_params) {
        $hash .=  $params->{$param};
    }
    $hash = $hash . reverse($main::Setup->novalnet_access_key);
    my $sha = sha256_hex($hash);
    return $sha;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getComments
    Parameters  : $payment_method, $payment_name, %response
    Returns     : string
    Description : To create transaction comments
=cut

sub getComments {
    my ($payment_method, $payment_name, %response) = @_;
    my @redirect_payments = ('novalnet_paypal', 'novalnet_ideal', 'novalnet_instantbank', 'novalnet_eps', 'novalnet_giropay','novalnet_przelewy24');
    
    push (@redirect_payments, 'novalnet_cc') if ($main::Setup->novalnet_cc_3d || $main::Setup->novalnet_cc_force_redirect);
    
    if (grep( /^$payment_method$/, @redirect_payments )) {
        decodeParams(\%response);
    }
    
    my $comments = '';
    
    if($response{'key'} == 40 || $response{'key'} == 41)
    {
		$comments .= getTranslatText("novalnet_guarantee_info").'<br><br>';
	}

    $comments .= ( $response{'test_mode'} == 1 ) ? getTranslatText("novalnet_test_mode") . '<br>' : '';
    $comments   .= getTranslatText("novalnet_payment_method") . ' : ' . $payment_name .'<br>';
    $comments   .= getTranslatText("novalnet_tid") . ' : ' . $response{'tid'} .'<br>';
	
	if($response{'key'} == 40 && $response{'tid_status'} == 75)
    {
		$comments .= '<br>'.getTranslatText("novalnet_guarantee_sepa_info").'<br>';
	} elsif($response{'key'} == 41 && $response{'tid_status'} == 75){
		$comments .= '<br>'.getTranslatText("novalnet_guarantee_invoice_info").'<br>';
	}
	
    my $invoice_comments = ( grep( /^$payment_method$/, ('novalnet_invoice', 'novalnet_prepayment') ) && $response{'tid_status'} != 75 ) ? invoiceComments($payment_method, %response) : '';
    
    my $cashpayment_comments = ( grep( /^$payment_method$/, ('novalnet_cashpayment') ) ) ? cashpaymentComments($payment_method, %response) : '';

    return $comments . $invoice_comments . $cashpayment_comments;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 invoiceComments
    Parameters  : $payment_method,%response
    Returns     : string
    Description : To create comments for invoice & prepayments
=cut

sub invoiceComments {
    my ($payment_method, %response) = @_;

    my $account_info  = '<br>' . getTranslatText("novalnet_transfer_amount_text") . '<br>';
    my $datum  = $response{'due_date'};
    
    if ($datum =~ /^(\d{4})\-(\d{2})\-(\d{2})$/) {
        $datum = "$3.$2.$1";
    }

    $account_info .= getTranslatText("novalnet_due_date_text") . ' : ' . $datum . '<br>' . getTranslatText("novalnet_account_holder_text") .$response{'invoice_account_holder'}. '<br>' . 'IBAN : ' . $response{'invoice_iban'} . '<br>' . 'BIC : ' . $response{'invoice_bic'} . '<br>Bank : ' . $response{'invoice_bankname'} . ' ' . $response{'invoice_bankplace'} . '<br>' . getTranslatText("novalnet_amount_text") . ' : ' . $response{'amount'} . ' ' .$response{'currency'} . '<br><br>';

    my $reference_info  = getTranslatText("novalnet_multi_reference") . '<br>';

    $reference_info .= '<br>' . getTranslatText("novalnet_reference_text1"). ' : ' . "BNR-" . $main::Setup->getSetupParameter('novalnet_product_id') . "-" . $response{'order_no'};
    $reference_info .= '<br>' . getTranslatText("novalnet_reference_text2"). ' : ' . 'TID ' . $response{'tid'};

    return $account_info . '<br>' . $reference_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 cashpaymentComments
    Parameters  : $payment_method,%response
    Returns     : string
    Description : To create comments for barzahlen payment
=cut

sub cashpaymentComments {
    my ($payment_method, %response) = @_;
    my $i;
    my $storeCount = 1;
    my $datum  = $response{'cp_due_date'};
    
    if ($datum =~ /^(\d{4})\-(\d{2})\-(\d{2})$/) {
        $datum = "$3.$2.$1";
    }

    my $account_info = '<br>' . getTranslatText("novalnet_cashpayment_slip_exp_date") . ' : ' . $datum .'<br><br>';
    $account_info .=  getTranslatText("novalnet_cashpayment_store").'<br><br>';
    
    foreach my $store (keys %response) {
		if (index($store, 'nearest_store_title') != -1) {
				++$storeCount;
		}
	}
    
	for ($i = 1; $i < $storeCount; ++$i) {
        $account_info .= $response{'nearest_store_title_'.$i}.'<br>';
        $account_info .= $response{'nearest_store_street_'.$i}.'<br>';
        $account_info .= $response{'nearest_store_city_'.$i}.'<br>';
        $account_info .= $response{'nearest_store_zipcode_'.$i}.'<br>';
        $account_info .= $response{'nearest_store_country_'.$i}.'<br><br>';
    }
    
    return $account_info;
    
}

#/////////////////////////////////////////////////////////////////////////////

=head2 isValidNumeric
    Parameters  : value
    Returns     : bool
    Description : To valiate the given value is numeric
=cut

sub isValidNumeric {
    my $value = @_;
    return 0 if ( @_ =~ /[^0-9]+|^$/ );
    return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 getTranslatText
    Parameters  : $key
    Returns     : string
    Description : To get translation string
=cut

sub getTranslatText {
    my $key  = shift;
    my $lang = $main::CosmoShop->getLanguage();
    return $main::Setup->getSetupParameter($lang . "_" . $key);
}
1;
