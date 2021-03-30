/**
 * Novalnet Admin action.
 *
 * @category  Novalnet Admin action
 * @package   Novalnet
 * @copyright Novalnet (https://www.novalnet.de)
 * @license   Novalnet AG
 */

/* Initiate Credit card process */
(function($){

    novalnetAdmin = {
        init : function (event) {
			
            novalnetAdmin.showOnholdLimit('novalnet_cc');
            novalnetAdmin.showOnholdLimit('novalnet_sepa');
            novalnetAdmin.showOnholdLimit('novalnet_paypal');
            novalnetAdmin.showOnholdLimit('novalnet_invoice');

            $('#novalnet_vendor_id, #novalnet_auth_code, #novalnet_product_id, #novalnet_access_key').prop('readonly', true);

            if ( $('#novalnet_product_activation_key').val() != undefined &&  $('#novalnet_product_activation_key').val() != '') {
                novalnetAdmin.sendAjaxCall();
            } else {
                novalnetAdmin.emptyValues();
            }
            $('#novalnet_product_activation_key').change(function () {
                if ( $('#novalnet_product_activation_key').val() != undefined &&  $('#novalnet_product_activation_key').val() != '') {
                    novalnetAdmin.sendAjaxCall();
                } else {
                    novalnetAdmin.emptyValues();
                }
            });
        },

        showOnholdLimit : function(payment) {
            if($('#'+ payment +'_transaction_type').val() == 'capture') {
                $( '.'+ payment +'_manual_limit' ).hide();
            }
            $('#'+ payment +'_transaction_type').on('change', function () {
                if ($( '#'+ payment +'_transaction_type option:selected' ).val() == 'authorize') {
                    $( '.'+ payment +'_manual_limit' ).show();
                } else {
                    $( '.'+ payment +'_manual_limit' ).hide();
                }
            });
        },
        sendAjaxCall: function() {
            var requestParams = {'hash' : $('#novalnet_product_activation_key').val()};
            $.ajax({
                url        :  "ajax/novalnet_autoconfig.cgi",
                type       : 'post',
                dataType   : 'html',
                data       :  requestParams,
                global     :  false,
                async      :  false,
                success    :  function (result) {
                    novalnetAdmin.handleResult(result);
                },
            });

        },
        handleResult: function(result) {
            var saved_tariff_id = $( '#novalnet_tariff_id' ).val();
            var response = $.parseJSON(result);
            if (response.status == '100') {
                $( '#novalnet_tariff_id' ).replaceWith( '<select id="novalnet_tariff_id" name= "novalnet_tariff_id" ></select>' );
                for ( var tariff_id in response.tariff ) {
                    var tariff_value = $.trim( response.tariff[ tariff_id ].name );
                    $( '#novalnet_tariff_id' ).append(
                        $(
                            '<option>', {
                                text : $.trim( tariff_value ),
                                value: $.trim( tariff_id )
                            }
                        )
                    );
                    if (saved_tariff_id == $.trim( tariff_id )) {
                        $('#novalnet_tariff_id').val(saved_tariff_id);
                    }
                }
                $('#novalnet_vendor_id').val(response.vendor);
                $('#novalnet_product_id').val(response.product);
                $('#novalnet_auth_code').val(response.auth_code);
                $('#novalnet_access_key').val(response.access_key);
            } else {
                    alert(response.config_result);
            }
        },
        emptyValues: function () {
            $('#novalnet_vendor_id, #novalnet_auth_code, #novalnet_product_id, #novalnet_access_key, #novalnet_tariff_id').val('');
        }
    };

    $( document ).ready(function() {
        novalnetAdmin.init();
    });

})( jQuery );
