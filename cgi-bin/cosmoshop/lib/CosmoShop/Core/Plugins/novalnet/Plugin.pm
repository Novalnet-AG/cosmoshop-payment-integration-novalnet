### CosmoShop Novalnet Package
### $Author: Novalnet $
### $Date: 2019-04-09 $

package CosmoShop::Core::Plugins::novalnet::Plugin;
use base CosmoShop::Core::Plugins::GenericPlugin;
use strict;

#/////////////////////////////////////////////////////////////////////////////

=head2 sendConfigHashCall
    Parameters  : params
    Parameters  : noAjax
    Returns     : json
    Description : To perform http request.
=cut

sub sendConfigHashCall {
    my $self = shift;
    my ($params, $noAjax) = @_;

    if (!$params) {
        return;
    }
    return $self->httpRequest( 'https://payport.novalnet.de/autoconfig', 'json', $params );
}

#/////////////////////////////////////////////////////////////////////////////

=head2 httpRequest
    Parameters  : $hash
    Returns     : hash
    Description : To perform http request.
=cut

sub httpRequest {
    my $self = shift;
    my ($url, $request_type, $request_data, $request_hash) = @_;

    use LWP::UserAgent;
    my $ua       = LWP::UserAgent->new();
    my ($comments, $response_content, $ua_response) = ('')x3;
    my (%response_hash, %http_response);

    if($request_type eq 'json') {
        $ua_response = $ua->post( $url, $request_data );
    } else {
        $ua_response = $ua->post( $url, $request_hash );
    }
    my $error_message = '';

    if ($ua_response->is_success) {
        $response_content = $ua_response->content();

        if($request_type eq 'json') {
            return $response_content;
        } else {
            %response_hash    = split /[&=]/, $response_content;
            return %response_hash;
        }
    } else {
        $http_response{'status'}   = $ua_response->status_line;
    }
    return %http_response;
}

1;

