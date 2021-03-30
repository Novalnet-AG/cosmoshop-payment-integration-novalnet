<html>
<body>
<?php
    if(isset($_GET['nn_callback'])) {
        $url = $_SERVER['SERVER_NAME'];
        $request = $_REQUEST;
        $request['action'] = 'handle_novalnet_notify';
        $request['ls'] = 'en';
        $request['reg_ip'] = $_SERVER['REMOTE_ADDR'];
        $handle = curl_init($url);
        curl_setopt($handle, CURLOPT_POST, true);
        curl_setopt($handle, CURLOPT_POSTFIELDS, $request);
        $response = curl_exec($handle);
        echo $response; exit;
    }
    if(!empty($_POST)) {
        $form = '<form action="'. $_POST['system_url'].'" method="post" id="nn_trans_form">';
        foreach($_POST as $key=>$value) {
            $form .= '<input type="hidden" name="'. $key .'" value="'. $value .'">';
        }
        $form .= '<input type="hidden" name="access_hash" value="'.(!empty($_POST['inputval3'])) ? $_POST['inputval3'] : $_POST['access_hash'].'">';
        $form .= '<input type="hidden" name="action" value="'.(!empty($_POST['inputval4'])) ? $_POST['inputval4'] : $_POST['action'].'">';
        $form .= '<input type="hidden" name="wkid" value="'.(!empty($_POST['inputval5'])) ? $_POST['inputval5'] : $_POST['wkid'].'">';
        $form .= '<input type="hidden" name="ls" value="'.(!empty($_POST['inputval6'])) ? $_POST['inputval6'] : $_POST['ls'].'">';
        $form .= '</form><script> document.getElementsByTagName("BODY")[0].style.display = "none"; document.getElementById("nn_trans_form").submit();</script>';
        echo $form;
    }
    else {
        header( 'Location: http://'.$_SERVER['SERVER_NAME']);
    }

?>
</body>
</html>

