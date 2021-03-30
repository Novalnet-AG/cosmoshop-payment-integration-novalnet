#!/usr/bin/perl
use strict;

BEGIN {
    require '../../lib/shopInit.pm';
    require 'all_admin.pl';
}

if ($main::Setup->pluginActive('novalnet')) {
    my $Request = $main::CosmoShop->getRequest();
    print "Content-type: application/json;charset=utf-8\n\n" unless $main::global_header_sent;
	my $parameter = {
		'hash' => $Request->getParameter()->{hash},
		'lang' => $main::CosmoShop->getBackendLanguage()
	};
	print $main::CosmoShop->Plugins->novalnet->sendConfigHashCall($parameter);
    
}
