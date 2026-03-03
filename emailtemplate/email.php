<?php
// CORS Headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

header('Content-Type: application/json');

// Include the mail function
require 'mail.php';

require_once __DIR__ . '/_config.php';
// API Key for authentication
$api_key = getenv('EMAIL_API_KEY') ?: $API_KEY;

// Validate API key
if (!isset($_POST['api_key']) || $_POST['api_key'] !== $api_key) {
    http_response_code(401);
    echo json_encode(["success" => false, "error" => "Unauthorized: Invalid API key"]);
    exit;
}



// Main action router
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
	// Get action from POST keys (e.g. signup=1, submitu=1, etc.)
	// Added 'send_receipt' to allow the client to request the server send a receipt URL to a customer email.
	$actions = ['signup', 'form-submit', 'declinew', 'submitu', 'thankyou', 'loandis', 'send_receipt'];
    $action = null;
    foreach ($actions as $a) {
        if (isset($_POST[$a])) {
            $action = $a;
            break;
        }
    }
    if (!$action) send_error("No valid action specified");

    switch ($action) {
				case 'send_simple':
					// Lightweight sender: accepts 'to', 'subject', and 'html' or 'message'
					$to = filter_input(INPUT_POST, 'to', FILTER_SANITIZE_EMAIL);
					$subject = isset($_POST['subject']) ? $_POST['subject'] : 'Notification from Global Thrive Alliance';
					$html = isset($_POST['html']) ? $_POST['html'] : (isset($_POST['message']) ? nl2br(htmlspecialchars($_POST['message'])) : '');

					if (!$to) send_error('Missing recipient (to)', 400);

					$headers = "MIME-Version: 1.0" . "\r\n";
					$headers .= "Content-type:text/html;charset=UTF-8" . "\r\n";
					$headers .= "From: Global Thrive Alliance <no-reply@" . $_SERVER['SERVER_NAME'] . ">" . "\r\n";

					$ok = mail($to, $subject, $html, $headers);
					if ($ok) echo json_encode(["success" => true, "message" => "Email sent"]);
					else { http_response_code(500); echo json_encode(["error" => "Failed to send email"]); }
					exit;

        case 'signup':
            // Required: email, name, gemail, egemail, phone
            $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $name = $_POST['name'] ?? '';
            $gemail = filter_input(INPUT_POST, 'gemail', FILTER_SANITIZE_EMAIL);
            $egemail = filter_input(INPUT_POST, 'egemail', FILTER_SANITIZE_EMAIL);
            $phone = $_POST['phone'] ?? '';

            function send_email($email){
        $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
        $name=$_POST['name'];
        //send email here
        send_mail($email,'welcome To Global thrive alliance',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance; Usercode</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
        html,
        body {
            margin: 0 auto !important;
            padding: 0 !important;
            height: 100% !important;
            width: 100% !important;
            background-color:rgb(19 43 38);
        }
        
        /* What it does: Stops email clients resizing small text. */
        * {
            -ms-text-size-adjust: 100%;
            -webkit-text-size-adjust: 100%;
        }
        
        /* What it does: Centers email on Android 4.4 */
        div[style*='margin: 16px 0'] {
            margin: 0 !important;
        }
        
        /* What it does: Stops Outlook from adding extra spacing to tables. */
        table,
        td {
            mso-table-lspace: 0pt !important;
            mso-table-rspace: 0pt !important;
        }
        
        /* What it does: Fixes webkit padding issue. */
        table {
            border-spacing: 0 !important;
            border-collapse: collapse !important;
            table-layout: fixed !important;
            margin: 0 auto !important;
        }
        
        /* What it does: Uses a better rendering method when resizing images in IE. */
        img {
            -ms-interpolation-mode:bicubic;
        }
        
        /* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
        a {
            text-decoration: none;
        }
        
        /* What it does: A work-around for email clients meddling in triggered links. */
        *[x-apple-data-detectors],  /* iOS */
        .unstyle-auto-detected-links *,
        .aBn {
            border-bottom: 0 !important;
            cursor: default !important;
            color: inherit !important;
            text-decoration: none !important;
            font-size: inherit !important;
            font-family: inherit !important;
            font-weight: inherit !important;
            line-height: inherit !important;
        }
        
        /* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
        .a6S {
            display: none !important;
            opacity: 0.01 !important;
        }
        
        /* What it does: Prevents Gmail from changing the text color in conversation threads. */
        .im {
            color: inherit !important;
        }
        
        /* If the above doesn't work, add a .g-img class to any image in question. */
        img.g-img + div {
            display: none !important;
        }
        
        /* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
        /* Create one of these media queries for each additional viewport size you'd like to fix */
        
        /* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
        @media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
            u ~ div .email-container {
                min-width: 320px !important;
            }
        }
        /* iPhone 6, 6S, 7, 8, and X */
        @media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
            u ~ div .email-container {
                min-width: 375px !important;
            }
        }
        /* iPhone 6+, 7+, and 8+ */
        @media only screen and (min-device-width: 414px) {
            u ~ div .email-container {
                min-width: 414px !important;
            }
        }
        
        
            </style>
        
            <!-- CSS Reset : END -->
        
            <!-- Progressive Enhancements : BEGIN -->
            <style>
        
                .primary{
            background: #dd0a35;
        }
        .bg_white{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_light{
            background:rgba(12, 50, 65, 0.8);
        }
        .bg_black{
            background: #0e2535;
        }
        .bg_dark{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_darka{
            background: rgba(12, 50, 65, 0.8);
        }
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(255,255,255,.5);
}

a{
	color:rgb(154, 169, 236);
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {


}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr>  
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg);background-position:center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
          <td class='bg_darka email-section' style='text-align:center; padding-top: 5em;'>
          	<div class='heading-section heading-section-white' style='    background: #1412126b;
			  padding: 30px;
			  border-radius: 25px;'>
          		<span class='subheading'>Dear ".$name."</span>
            	<p><h2>Welcome To Global Thrive Alliance</h2><br>
				<p><h4> We are thrilled to have you join us. Learn more about us from our site.<p><a href='https://globalthrivealliance.com' class='btn btn-primary'>Read more</a></p></h4>
                <p><h4> Please note that emails have been sent to both your internal and external guarantors but do see to it that they fill the respective forms linked to their emails as you may not be able to join us without it<p></h4>               
                <p><h4> Share this link with your internal guarantor<p><a href='' >https://globalthrivealliance.com/consenti.html</a></p></h4>
                <p><h4> Share this link with your external guarantor<p><a href='' >https://globalthrivealliance.com/consente.html</a></p></h4>
               
                <p> You would be assigned a usercode which would be your identification tag for the cooperative. Please do not forget it as it is important for your cooperative rights.</p>
				
            	</div>
          </td>
        </tr><!-- end: tr -->.
      <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
						<tr>
							<td style='text-align: left; padding-right: 10px;'>
								<p>Contact us:<br> <span><a href='mailto:contact@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
									         <a href='tel:2348069648432'>
                <span>+2348069648432</span>
              </a></span><br><a href='tel:+447479454857'>
                <span style='text-decoration: none;color: white;'>
                  +447479454857
                </span>
              </a></span><br>
			  <a href='https://wa.link/bc1z0r' target='_blank' >
            <img src='https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg' alt='WhatsApp' class='whatsapp-icon'>
        </a></span></p>
							</td>
						  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>" );
    }
   
    send_email($email);
     function send_emaila($gemail){
        $gemail = filter_input(INPUT_POST, 'gemail', FILTER_SANITIZE_EMAIL);
        $fname=$_POST['fname'];
         $Phone=$_POST['Phone'];

 
        //send email here
        send_mail($gemail,'Internal guarantor approval',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance; Approval</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
        html,
        body {
            margin: 0 auto !important;
            padding: 0 !important;
            height: 100% !important;
            width: 100% !important;
            background-color:rgb(19 43 38);
        }
        
        /* What it does: Stops email clients resizing small text. */
        * {
            -ms-text-size-adjust: 100%;
            -webkit-text-size-adjust: 100%;
        }
        
        /* What it does: Centers email on Android 4.4 */
        div[style*='margin: 16px 0'] {
            margin: 0 !important;
        }
        
        /* What it does: Stops Outlook from adding extra spacing to tables. */
        table,
        td {
            mso-table-lspace: 0pt !important;
            mso-table-rspace: 0pt !important;
        }
        
        /* What it does: Fixes webkit padding issue. */
        table {
            border-spacing: 0 !important;
            border-collapse: collapse !important;
            table-layout: fixed !important;
            margin: 0 auto !important;
        }
        
        /* What it does: Uses a better rendering method when resizing images in IE. */
        img {
            -ms-interpolation-mode:bicubic;
        }
        
        /* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
        a {
            text-decoration: none;
        }
        
        /* What it does: A work-around for email clients meddling in triggered links. */
        *[x-apple-data-detectors],  /* iOS */
        .unstyle-auto-detected-links *,
        .aBn {
            border-bottom: 0 !important;
            cursor: default !important;
            color: inherit !important;
            text-decoration: none !important;
            font-size: inherit !important;
            font-family: inherit !important;
            font-weight: inherit !important;
            line-height: inherit !important;
        }
        
        /* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
        .a6S {
            display: none !important;
            opacity: 0.01 !important;
        }
        
        /* What it does: Prevents Gmail from changing the text color in conversation threads. */
        .im {
            color: inherit !important;
        }
        
        /* If the above doesn't work, add a .g-img class to any image in question. */
        img.g-img + div {
            display: none !important;
        }
        
        /* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
        /* Create one of these media queries for each additional viewport size you'd like to fix */
        
        /* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
        @media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
            u ~ div .email-container {
                min-width: 320px !important;
            }
        }
        /* iPhone 6, 6S, 7, 8, and X */
        @media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
            u ~ div .email-container {
                min-width: 375px !important;
            }
        }
        /* iPhone 6+, 7+, and 8+ */
        @media only screen and (min-device-width: 414px) {
            u ~ div .email-container {
                min-width: 414px !important;
            }
        }
        
        
            </style>
        
            <!-- CSS Reset : END -->
        
            <!-- Progressive Enhancements : BEGIN -->
            <style>
        
                .primary{
            background: #dd0a35;
        }
        .bg_white{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_light{
            background:rgba(12, 50, 65, 0.8);
        }
        .bg_black{
            background: #0e2535;
        }
        .bg_dark{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_darka{
            background: rgba(12, 50, 65, 0.8);
        }
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(255,255,255,.5);
}

a{
	color:rgb(149, 162, 219);
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {


}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr>  
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg); background-position:center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
          <td class='bg_dark email-section' style='text-align:center; padding-top: 5em;'>
          	<div class='heading-section heading-section-white'style='    background: #1412126b;
			  padding: 30px;
			  border-radius: 25px;'>
          		<span >approval required</span>
            	<p><h2 class='subheading'>Guarantor approval</h2><br>
				<p><h4>Approval required</h4>
				<h3 >".$fname."</h3><br><h3>".$Phone."</h3></p></p>
                <p>Please click this link to fill the guarantor consent form if you agree to be this applicants guarantor<br><a href='https://globalthrivealliance.com/consenti.html'class='btn btn-primary'>Click me</a>
                  </p>
				<p>The name and phone number above have been submitted in a request to join our cooperative with you being their guarantor.  You can ignore this confirmation email if you do not approve of it. </p>
				<p>If you do have any issues with this please contact us via email <a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br> Or call: <a href='tel:+234-8069648432'>+2348069648432</a></p>

            	</div>
          </td>
        </tr><!-- end: tr -->
        <tr>
          			<td style='padding-bottom: 30px;'>
          				<table role='presentation' border='0' cellpadding='0' cellspacing='0' width='100%'>
          					
		                <td valign='middle' width='70%'>
		                  <div class='text-program' style='text-align: left; padding-left:25px;'>
		                  	<p class='meta'><span>Please do read</span> <span>and contact us immediately if you do not agree to this</span></p>
				              	<h2>Guarantor Pledge</h2>
				              	<p>            
                                  Consent Statement:
                                  <br>I, a member in good standing of Global Thrive Alliance, hereby provide my explicit consent to guarantee the membership application of [Applicant].
                                  <br>I confirm that I have:
                                  <br>Read and fully understood the bylaws, rules, and regulations of Global Thrive Alliance.<a href='https://globalthrivealliance.com/bylaws.html' >Read bylaws</a>
                                  <br> Read and fully understood the Alliance's data privacy policy.<a href='https://globalthrivealliance.com/privacy.html' >Read Privacy policy</a>
                                  <br> Comprehended that by providing this consent, I am vouching for the Applicant's character, integrity, and commitment to the Alliance's objectives.
                                  <br> Understood that I am responsible for mentoring and guiding the Applicant during their initial period of membership, as specified in the Guarantor Agreement.
                                  <br> Acknowledged that I am not financially liable for any financial obligations of the applicant.
                                  <br>I understand that this consent is a necessary requirement for the Applicant's membership in Global Thrive Alliance
                                  <br>I, the undersigned Guarantor, hereby unconditionally and irrevocably guarantee the repayment of the loan granted to the above-named Applicant by GLOBALTHRIVEALLIANCE LTD, up to the full amount of the loan principal plus any accrued interest, fees, and other charges, as specified in the loan agreement.
                               </p>
				              	<p>By filling the form linked to this email you give your consent to beint the applicants internal guarantor</p>
		                  </div>
		                </td>
          				</table>
          			</td>
              </tr><!-- end: tr -->.
      <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
						<tr>
							<td style='text-align: left; padding-right: 10px;'>
								<p>Contact us:<br> <span><a href='mailto:contact@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
									         <a href='tel:2348069648432'>
                <span>+2348069648432</span>
              </a></span><br><a href='tel:+447479454857'>
                <span style='text-decoration: none;color: white;'>
                  +447479454857
                </span>
              </a></span><br>
			  <a href='https://wa.link/bc1z0r' target='_blank' >
            <img src='https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg' alt='WhatsApp' class='whatsapp-icon'>
        </a></span></p>
							</td>
						  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>" );
    }
   
    send_emaila($gemail);
    function send_emailb($egemail){
        $fname=$_POST['fname'];
        $egemail = filter_input(INPUT_POST, 'egemail', FILTER_SANITIZE_EMAIL);
        $Phone=$_POST['Phone'];
 
        //send email here
        send_mail($egemail,'External guarantor approval GTA',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance; Usercode</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
        html,
        body {
            margin: 0 auto !important;
            padding: 0 !important;
            height: 100% !important;
            width: 100% !important;
            background-color:rgb(19 43 38);
        }
        
        /* What it does: Stops email clients resizing small text. */
        * {
            -ms-text-size-adjust: 100%;
            -webkit-text-size-adjust: 100%;
        }
        
        /* What it does: Centers email on Android 4.4 */
        div[style*='margin: 16px 0'] {
            margin: 0 !important;
        }
        
        /* What it does: Stops Outlook from adding extra spacing to tables. */
        table,
        td {
            mso-table-lspace: 0pt !important;
            mso-table-rspace: 0pt !important;
        }
        
        /* What it does: Fixes webkit padding issue. */
        table {
            border-spacing: 0 !important;
            border-collapse: collapse !important;
            table-layout: fixed !important;
            margin: 0 auto !important;
        }
        
        /* What it does: Uses a better rendering method when resizing images in IE. */
        img {
            -ms-interpolation-mode:bicubic;
        }
        
        /* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
        a {
            text-decoration: none;
        }
        
        /* What it does: A work-around for email clients meddling in triggered links. */
        *[x-apple-data-detectors],  /* iOS */
        .unstyle-auto-detected-links *,
        .aBn {
            border-bottom: 0 !important;
            cursor: default !important;
            color: inherit !important;
            text-decoration: none !important;
            font-size: inherit !important;
            font-family: inherit !important;
            font-weight: inherit !important;
            line-height: inherit !important;
        }
        
        /* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
        .a6S {
            display: none !important;
            opacity: 0.01 !important;
        }
        
        /* What it does: Prevents Gmail from changing the text color in conversation threads. */
        .im {
            color: inherit !important;
        }
        
        /* If the above doesn't work, add a .g-img class to any image in question. */
        img.g-img + div {
            display: none !important;
        }
        
        /* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
        /* Create one of these media queries for each additional viewport size you'd like to fix */
        
        /* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
        @media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
            u ~ div .email-container {
                min-width: 320px !important;
            }
        }
        /* iPhone 6, 6S, 7, 8, and X */
        @media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
            u ~ div .email-container {
                min-width: 375px !important;
            }
        }
        /* iPhone 6+, 7+, and 8+ */
        @media only screen and (min-device-width: 414px) {
            u ~ div .email-container {
                min-width: 414px !important;
            }
        }
        
        
            </style>
        
            <!-- CSS Reset : END -->
        
            <!-- Progressive Enhancements : BEGIN -->
            <style>
        
                .primary{
            background: #dd0a35;
        }
        .bg_white{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_light{
            background:rgba(12, 50, 65, 0.8);
        }
        .bg_black{
            background: #0e2535;
        }
        .bg_dark{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_darka{
            background: rgba(12, 50, 65, 0.8);
        }
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(255,255,255,.5);
}

a{
	color:rgb(109, 131, 226);
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {


}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr>  
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg);background-position:center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
          <td class='bg_darka email-section' style='text-align:center; padding-top: 5em;'>
          	<div class='heading-section heading-section-white' style='    background: #1412126b;
			  padding: 30px;
			  border-radius: 25px;'>
              <span >approval required</span>
              <p><h2 class='subheading'>Guarantor approval</h2><br>
              <p><h4>Approval required</h4>
              <h3 >".$fname."</h3><br><h3>".$Phone."</h3></p></p>
              <p>Please click this link to fill the guarantor consent form if you agree to be this applicants guarantor<br><a href='https://globalthrivealliance.com/consente.html'class='btn btn-primary'>Click me</a></p>
                 <p>The name and phone number above have been submitted in a request to join our cooperative with you being their guarantor.  You can ignore this confirmation email if you do not approve of it. </p>
              <p>If you do have any issues with this please contact us via email <a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br> Or call: <a href='tel:+234-8069648432'>+2348069648432</a></p>

              </div>
        </td>
      </tr><!-- end: tr -->
      <tr>
                    <td style='padding-bottom: 30px;'>
                        <table role='presentation' border='0' cellpadding='0' cellspacing='0' width='100%'>
                            
                      <td valign='middle' width='70%'>
                        <div class='text-program' style='text-align: left; padding-left:25px;'>
                            <p class='meta'><span>Please do read</span> <span>and contact us immediately if you do not agree to this</span></p>
                                <h2>Guarantor Pledge</h2>
                                <p>            
                                GUARANTOR CONSENT FORM - GLOBAL THRIVE ALLIANCE (Non-Member Guarantor)
<br>Consent Statement:
<br>I, hereby provide my explicit consent to guarantee the membership application of [Applicant's Full Name] to Global Thrive Alliance.
<br>I confirm that I have:
<br> Read and fully understood the bylaws, rules, and regulations of Global Thrive Alliance (provided to me).
<br>Read and fully understood the Alliance's data privacy policy (provided to me).
<br> Comprehended that by providing this consent, I am vouching for the Applicant's character, integrity, and commitment to the Alliance's objectives.
<br> Understand that I am attesting to the Applicant's suitability for membership in Global Thrive Alliance, based on my knowledge of them.
<br>Acknowledged that I am not financially liable for any financial obligations of the applicant to Global Thrive Alliance.
 
<br> Understand that I may be contacted by Global Thrive Alliance to verify the information provided.
<br>I understand that this consent is a necessary requirement for the Applicant's membership in Global Thrive Alliance
                               </p>
                                <p>By filling the form linked to this email you give your consent to beint the applicants external guarantor</p>
                        </div>
                      </td>
                        </table>
                    </td>
            </tr><!-- end: tr -->. <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
						<tr>
							<td style='text-align: left; padding-right: 10px;'>
								<p>Contact us:<br> <span><a href='mailto:contact@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
									         <a href='tel:2348069648432'>
                <span>+2348069648432</span>
              </a></span><br><a href='tel:+447479454857'>
                <span style='text-decoration: none;color: white;'>
                  +447479454857
                </span>
              </a></span><br>
			  <a href='https://wa.link/bc1z0r' target='_blank' >
            <img src='https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg' alt='WhatsApp' class='whatsapp-icon'>
        </a></span></p>
							</td>
						  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>" );
    }
   
    send_emailb($egemail);
            echo json_encode(["success" => true, "message" => "Signup emails sent"]);
            exit;

		case 'send_receipt':
			// Expected POST fields: 'to' (recipient email), 'receipt_url', optional 'subject' and 'message'
			$to = filter_input(INPUT_POST, 'to', FILTER_SANITIZE_EMAIL);
			$receipt_url = filter_input(INPUT_POST, 'receipt_url', FILTER_SANITIZE_URL);
			$subject = isset($_POST['subject']) ? $_POST['subject'] : 'Your receipt from Global Thrive Alliance';
			$message = isset($_POST['message']) ? $_POST['message'] : "Hello,\n\nPlease find your receipt at: $receipt_url\n\nThank you.";

			if (!$to || !$receipt_url) {
				send_error('Missing recipient or receipt URL', 400);
			}

			// Compose a minimal HTML body including the provided message and the receipt link
			$html = "<p>Hello,</p>" . "<p>" . nl2br(htmlspecialchars($message)) . "</p>" . "<p><a href=\"$receipt_url\">Download Receipt</a></p>" . "<p>Thank you.</p>";

			// Use the project's send helper (PHPMailer-backed) and pass the composed HTML.
			// The helper `send_mail($to, $subject, $html)` is used elsewhere in this file.
			$ok = false;
			try {
				$ok = send_mail($to, $subject, $html);
			} catch (Exception $e) {
				$ok = false;
			}

			if ($ok) {
				echo json_encode(["success" => true, "message" => "Email sent"]);
			} else {
				http_response_code(500);
				echo json_encode(["error" => "Failed to send email"]);
			}
			exit;

        case 'form-submit':
            // Required: guarantoremail, fname, phone, amount
            $guarantoremail = filter_input(INPUT_POST, 'guarantoremail', FILTER_SANITIZE_EMAIL);
            $fname = $_POST['fname'] ?? '';
            $phone = $_POST['phone'] ?? '';
            $amount = $_POST['amount'] ?? '';

              function send_email($guarantoremail){
        $guarantoremail = filter_input(INPUT_POST, 'guarantoremail', FILTER_SANITIZE_EMAIL);
            $fname = $_POST['fname'] ?? '';
            $phone = $_POST['phone'] ?? '';
            $amount = $_POST['amount'] ?? '';
        //send email here
        send_mail($guarantoremail,'Guarantor approval',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance;Loan Guarantor confirmation</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
        html,
		body {
			margin: 0 auto !important;
			padding: 0 !important;
			height: 100% !important;
			width: 100% !important;
			background-color:rgb(19 43 38);
		}
		
		/* What it does: Stops email clients resizing small text. */
		* {
			-ms-text-size-adjust: 100%;
			-webkit-text-size-adjust: 100%;
		}
		
		/* What it does: Centers email on Android 4.4 */
		div[style*='margin: 16px 0'] {
			margin: 0 !important;
		}
		
		/* What it does: Stops Outlook from adding extra spacing to tables. */
		table,
		td {
			mso-table-lspace: 0pt !important;
			mso-table-rspace: 0pt !important;
		}
		
		/* What it does: Fixes webkit padding issue. */
		table {
			border-spacing: 0 !important;
			border-collapse: collapse !important;
			table-layout: fixed !important;
			margin: 0 auto !important;
		}
		
		/* What it does: Uses a better rendering method when resizing images in IE. */
		img {
			-ms-interpolation-mode:bicubic;
		}
		
		/* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
		a {
			text-decoration: none;
		}
		
		/* What it does: A work-around for email clients meddling in triggered links. */
		*[x-apple-data-detectors],  /* iOS */
		.unstyle-auto-detected-links *,
		.aBn {
			border-bottom: 0 !important;
			cursor: default !important;
			color: inherit !important;
			text-decoration: none !important;
			font-size: inherit !important;
			font-family: inherit !important;
			font-weight: inherit !important;
			line-height: inherit !important;
		}
		
		/* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
		.a6S {
			display: none !important;
			opacity: 0.01 !important;
		}
		
		/* What it does: Prevents Gmail from changing the text color in conversation threads. */
		.im {
			color: inherit !important;
		}
		
		/* If the above doesn't work, add a .g-img class to any image in question. */
		img.g-img + div {
			display: none !important;
		}
		
		/* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
		/* Create one of these media queries for each additional viewport size you'd like to fix */
		
		/* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
		@media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
			u ~ div .email-container {
				min-width: 320px !important;
			}
		}
		/* iPhone 6, 6S, 7, 8, and X */
		@media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
			u ~ div .email-container {
				min-width: 375px !important;
			}
		}
		/* iPhone 6+, 7+, and 8+ */
		@media only screen and (min-device-width: 414px) {
			u ~ div .email-container {
				min-width: 414px !important;
			}
		}
		
		
			</style>
		
			<!-- CSS Reset : END -->
		
			<!-- Progressive Enhancements : BEGIN -->
			<style>
		
				.primary{
			background: #dd0a35;
		}
		.bg_white{
			background: rgba(19, 48, 41, 0.8);
		}
		.bg_light{
			background:rgba(12, 50, 65, 0.8);
		}
		.bg_black{
			background: #0e2535;
		}
		.bg_dark{
			background: rgba(19, 48, 41, 0.8);
		}
		.bg_darka{
			background: rgba(12, 50, 65, 0.8);
		}
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(255,255,255,.5);
}

a{
	color:rgb(100, 118, 199);
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {


}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr> 
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg);background-position:center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            			
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
          <td class='bg_dark email-section' style='text-align:center; padding-top: 5em;'>
          	<div class='heading-section heading-section-white'style='    background: #1412126b;
			  padding: 30px;
			  border-radius: 25px;'>
          		<span >Dear valued user, </span>
            	<p><h2 class='subheading'>Loan Guarantor approval</h2><br>
				<p><h4>Approval required</h4>
				<h3 >".$fname."</h3><br><h3>".$phone."</h3></p></p>
				<p>The name and phone number above have been submitted in a request to take out a loan of ".$amount." from our cooperative with you being their guarantor.  You can ignore this confirmation email if you approve of it.<br>Please read through terms and conditions bellow and fill this form <br> <a class='btn btn-primary' href='https://globalthrivealliance.com/loanguarantor.html'>Loan guarantor form</a> </p>
				<p>If you do not approve of this please contact us via email <a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br> Or call: <a href='tel:+234-8069648432'>+234-8069648432</a></p>

            	</div>
          </td>
        </tr><!-- end: tr -->
        <tr>
          			<td style='padding-bottom: 30px;'>
          				<table role='presentation' border='0' cellpadding='0' cellspacing='0' width='100%'>
          					
		                <td valign='middle' width='70%'>
		                  <div class='text-program' style='text-align: left; padding-left:25px;'>
		                  	<p class='meta'><span>Please do read</span> <span>and contact us immediately if you do not agree to this</span></p>
				              	<h2>Guarantor Pledge</h2>
				              	<p>
                                  I, the undersigned Guarantor, hereby unconditionally and irrevocably guarantee the repayment of the loan granted to the above-named Applicant by GLOBALTHRIVEALLIANCE LTD, up to the full amount of the loan principal plus any accrued interest, fees, and other charges, as specified in the loan agreement.
                                 <Br> I understand and agree that:
                                   <br> This guarantee is a continuing guarantee and shall remain in full force and effect until the loan is fully repaid, regardless of any changes in the terms of the loan agreement, unless explicitly released in writing by the Cooperative.
                                   <br> I am jointly and severally liable with the Applicant for the repayment of the loan.  This means the Cooperative can demand payment from me without first trying to collect from the Applicant.
                                   <br> I have reviewed and understand the terms and conditions of the loan agreement between the Applicant and the Cooperative.
                                   <br> I am aware of the Applicant's financial situation and believe they are capable of repaying the loan.  However, I understand that my guarantee is independent of the Applicant's ability to repay.
                                   <br>I will immediately notify the Cooperative in writing of any changes to my contact information or financial situation.
                                   <br> I understand that the Cooperative may pursue legal action against me to recover any outstanding amounts in the event of default by the Applicant.
                                  <br><h2>Declaration:</h2><Br>
                                  I declare that the information provided in this form is true and accurate to the best of my knowledge and belief. I have read and understood the terms and conditions of this guarantee and agree to be bound by them.
                                  </p>
				              	<p><a href='https://globalthrivealliance.com' class='btn btn-primary'>Read more</a></p>
		                  </div>
		                </td>
          				</table>
          			</td>
              </tr>
         <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
					  <tr>
						<td style='text-align: left; padding-right: 10px;'>
							<p>Contact us:<br> <span><a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
								<a href='tel:+234-9076-36728'>2349076367238</a></span></p>
						</td>
					  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>");}
send_email($email);
            echo json_encode(["success" => true, "message" => "Guarantor email sent"]);
            exit;

        case 'declinew':
            // Required: email, reason, amount
            $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $reason = $_POST['reason'] ?? '';
            $amount = $_POST['amount'] ?? '';

             function send_email($email){
         $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $reason = $_POST['reason'] ?? '';
            $amount = $_POST['amount'] ?? '';
 
        //send email here
        send_mail($email,'Declined Withdrawal',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance; declined contribution payment</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
        html,
body {
    margin: 0 auto !important;
    padding: 0 !important;
    height: 100% !important;
    width: 100% !important;
    background:rgb(22, 18, 18);
}

/* What it does: Stops email clients resizing small text. */
* {
    -ms-text-size-adjust: 100%;
    -webkit-text-size-adjust: 100%;
}

/* What it does: Centers email on Android 4.4 */
div[style*='margin: 16px 0'] {
    margin: 0 !important;
}

/* What it does: Stops Outlook from adding extra spacing to tables. */
table,
td {
    mso-table-lspace: 0pt !important;
    mso-table-rspace: 0pt !important;
}

/* What it does: Fixes webkit padding issue. */
table {
    border-spacing: 0 !important;
    border-collapse: collapse !important;
    table-layout: fixed !important;
    margin: 0 auto !important;
}

/* What it does: Uses a better rendering method when resizing images in IE. */
img {
    -ms-interpolation-mode:bicubic;
}

/* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
a {
    text-decoration: none;
}

/* What it does: A work-around for email clients meddling in triggered links. */
*[x-apple-data-detectors],  /* iOS */
.unstyle-auto-detected-links *,
.aBn {
    border-bottom: 0 !important;
    cursor: default !important;
    color: inherit !important;
    text-decoration: none !important;
    font-size: inherit !important;
    font-family: inherit !important;
    font-weight: inherit !important;
    line-height: inherit !important;
}

/* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
.a6S {
    display: none !important;
    opacity: 0.01 !important;
}

/* What it does: Prevents Gmail from changing the text color in conversation threads. */
.im {
    color: inherit !important;
}

/* If the above doesn't work, add a .g-img class to any image in question. */
img.g-img + div {
    display: none !important;
}

/* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
/* Create one of these media queries for each additional viewport size you'd like to fix */

/* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
@media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
    u ~ div .email-container {
        min-width: 320px !important;
    }
}
/* iPhone 6, 6S, 7, 8, and X */
@media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
    u ~ div .email-container {
        min-width: 375px !important;
    }
}
/* iPhone 6+, 7+, and 8+ */
@media only screen and (min-device-width: 414px) {
    u ~ div .email-container {
        min-width: 414px !important;
    }
}


    </style>

    <!-- CSS Reset : END -->

    <!-- Progressive Enhancements : BEGIN -->
    <style>

	    .primary{
	background: #dd0a35;
}
.bg_white{
	background: #ffffff;
}
.bg_light{
	background: #fafafa;
}
.bg_black{
	background: #000000;
}
.bg_dark{
	background: rgba(0,0,0,.8);
}
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(255,255,255,.5);
}

a{
	color: #0b1956;
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {


}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr> 
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg); background-position: center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
          <td class='bg_dark email-section' style='text-align:center; padding-top: 5em;'>
          	<div class='heading-section heading-section-white'style='    background: #1412126b;
			  padding: 30px;
			  border-radius: 25px;'>
          		<span >Dear valued user,</span>
                  <p><h2 class='subheading'>Declined Withdrawal</h2><br>
                  <p><h4>withdrawal application declined</h4>
                  <h3 >Your withdrawal application of ".$amount." was declined due to: ".$reason.".</h3></p></p>
                  <p>To apply again please visit your <a class='btn btn-primary' href='https://globalthrivealliance.com/auth/Withdraw.php'>Withdraw page</a> </p>
                  <p>For more help please visit <a class='btn btn-primary' href='https://globalthrivealliance.com/help.html'>Help</a> </p>
                  <p>If you do not approve of this please contact us via email <a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br> Or call: <a href='tel:+234-9076-36728'>2349076367238</a></p>
  
            	</div>
          </td>
        </tr><!-- end: tr -->
         <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
					  <tr>
						<td style='text-align: left; padding-right: 10px;'>
							<p>Contact us:<br> <span><a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
								<a href='tel:+234-9076-36728'>2349076367238</a></span></p>
						</td>
					  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>");}
send_email($email);
            echo json_encode(["success" => true, "message" => "Decline email sent"]);
            exit;

        case 'submitu':
            // Required: email, usercode
            $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $usercode = $_POST['usercode'] ?? '';

              function send_email($email){
      $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $usercode = $_POST['usercode'] ?? '';
 
        //send email here
        send_mail($email,'usercode',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance; Usercode</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
        html,
        body {
            margin: 0 auto !important;
            padding: 0 !important;
            height: 100% !important;
            width: 100% !important;
            background-color:rgb(19 43 38);
        }
        
        /* What it does: Stops email clients resizing small text. */
        * {
            -ms-text-size-adjust: 100%;
            -webkit-text-size-adjust: 100%;
        }
        
        /* What it does: Centers email on Android 4.4 */
        div[style*='margin: 16px 0'] {
            margin: 0 !important;
        }
        
        /* What it does: Stops Outlook from adding extra spacing to tables. */
        table,
        td {
            mso-table-lspace: 0pt !important;
            mso-table-rspace: 0pt !important;
        }
        
        /* What it does: Fixes webkit padding issue. */
        table {
            border-spacing: 0 !important;
            border-collapse: collapse !important;
            table-layout: fixed !important;
            margin: 0 auto !important;
        }
        
        /* What it does: Uses a better rendering method when resizing images in IE. */
        img {
            -ms-interpolation-mode:bicubic;
        }
        
        /* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
        a {
            text-decoration: none;
        }
        
        /* What it does: A work-around for email clients meddling in triggered links. */
        *[x-apple-data-detectors],  /* iOS */
        .unstyle-auto-detected-links *,
        .aBn {
            border-bottom: 0 !important;
            cursor: default !important;
            color: inherit !important;
            text-decoration: none !important;
            font-size: inherit !important;
            font-family: inherit !important;
            font-weight: inherit !important;
            line-height: inherit !important;
        }
        
        /* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
        .a6S {
            display: none !important;
            opacity: 0.01 !important;
        }
        
        /* What it does: Prevents Gmail from changing the text color in conversation threads. */
        .im {
            color: inherit !important;
        }
        
        /* If the above doesn't work, add a .g-img class to any image in question. */
        img.g-img + div {
            display: none !important;
        }
        
        /* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
        /* Create one of these media queries for each additional viewport size you'd like to fix */
        
        /* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
        @media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
            u ~ div .email-container {
                min-width: 320px !important;
            }
        }
        /* iPhone 6, 6S, 7, 8, and X */
        @media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
            u ~ div .email-container {
                min-width: 375px !important;
            }
        }
        /* iPhone 6+, 7+, and 8+ */
        @media only screen and (min-device-width: 414px) {
            u ~ div .email-container {
                min-width: 414px !important;
            }
        }
        
        
            </style>
        
            <!-- CSS Reset : END -->
        
            <!-- Progressive Enhancements : BEGIN -->
            <style>
        
                .primary{
            background: #dd0a35;
        }
        .bg_white{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_light{
            background:rgba(12, 50, 65, 0.8);
        }
        .bg_black{
            background: #0e2535;
        }
        .bg_dark{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_darka{
            background: rgba(12, 50, 65, 0.8);
        }
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(255,255,255,.5);
}

a{
	color:rgb(86, 125, 170);
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {


}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr>  
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg); background-position:center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
          <td class='bg_darka email-section' style='text-align:center; padding-top: 5em;'>
          	<div class='heading-section heading-section-white' style='    background: #1412126b;
			  padding: 30px;
			  border-radius: 25px;'>
          		<span class='subheading'>Welcome</span>
            	<p><h2>Welcome To Global Thrive Alliance</h2><br>
				<p><h4>your user code is:</h4>
				<h1 class='subheading' style='font-size:xx-large ;'>".$usercode."</h1></p></p>
				<p><a href='https://globalthrivealliance.com/auth/login.php' class='btn btn-primary'>Login</a></p>
            	</div>
          </td>
        </tr><!-- end: tr -->
          <tr>
	        <td class='bg_dark email-section'>
	        	<div class='heading-section' style='text-align: center; padding: 0 30px;'>
	        		
	          	<h3 class='subheading'>Please note:</h3>
	        	</div>
	        	<table role='presentation' border='0' cellpadding='0' cellspacing='0' width='100%'>
	        		
              <tr>
          			<td style='padding-bottom: 30px;'>
          				<table role='presentation' border='0' cellpadding='0' cellspacing='0' width='100%'>
          					<tr valign='middle' width='50%'>
		                  <img src='https://globalthrivealliance.com/images/about-img2.png' alt='' style='width: 70%; border-radius: 25px; max-width: 600px; height: auto; margin: auto; display: block;'>
		                </tr>
		                <tr valign='middle' width='50%'>
		                  <div class='text-program' style='text-align: left; padding-left:25px;'>
				              	<h2>User code information</h2>
				              	<p>Please do note that your user code (".$usercode.") and email (".$email.") is your identification tag for the cooperative and should not be forgotten or tempered with as ther play integral roles to accessing your cooperative rites.</p>
				              	<p><a href='https://globalthrivealliance.com' class='btn btn-primary'>Read more</a></p>
                                  <p>Please do make sure to read through our by laws.</p>
				              	<p><a href='https://globalthrivealliance.com/bylaws.html' class='btn btn-primary'>Read our bylaws</a></p>
		                  </div>
		                </tr>
          				</table>
          			</td>
              </tr>
          	</table>
          </td>
        </tr> <!-- end: tr -->
      <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
						<tr>
							<td style='text-align: left; padding-right: 10px;'>
								<p>Contact us:<br> <span><a href='mailto:contact@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
									<a href='tel:+234-9076-36728'>2349076367238</a></span></p>
							</td>
						  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>");}
send_email($email);

            echo json_encode(["success" => true, "message" => "Usercode email sent"]);
            exit;

        case 'thankyou':
            // Required: email, fname, balance, amountcon, adminfee, datebalanceu
            $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $fname = $_POST['fname'] ?? '';
            $balance = $_POST['balance'] ?? '';
            $amountcon = $_POST['amountcon'] ?? '';
            $adminfee = $_POST['adminfee'] ?? '';
            $datebalanceu = $_POST['datebalanceu'] ?? '';

            function send_emailf($email, $conn){
    
  $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $fname = $_POST['fname'] ?? '';
            $balance = $_POST['balance'] ?? '';
            $amountcon = $_POST['amountcon'] ?? '';
            $adminfee = $_POST['adminfee'] ?? '';
            $datebalanceu = $_POST['datebalanceu'] ?? '';
   

    //send email here
    send_mail($email,'Thanks from GTA',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance; Thank You!!!!</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
		html,
body {
    margin: 0 auto !important;
    padding: 0 !important;
    height: 100% !important;
    width: 100% !important;
	background-color:rgb(19 43 38);
}

/* What it does: Stops email clients resizing small text. */
* {
    -ms-text-size-adjust: 100%;
    -webkit-text-size-adjust: 100%;
}

/* What it does: Centers email on Android 4.4 */
div[style*='margin: 16px 0'] {
    margin: 0 !important;
}

/* What it does: Stops Outlook from adding extra spacing to tables. */
table,
td {
    mso-table-lspace: 0pt !important;
    mso-table-rspace: 0pt !important;
}

/* What it does: Fixes webkit padding issue. */
table {
    border-spacing: 0 !important;
    border-collapse: collapse !important;
    table-layout: fixed !important;
    margin: 0 auto !important;
}

/* What it does: Uses a better rendering method when resizing images in IE. */
img {
    -ms-interpolation-mode:bicubic;
}

/* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
a {
    text-decoration: none;
}

/* What it does: A work-around for email clients meddling in triggered links. */
*[x-apple-data-detectors],  /* iOS */
.unstyle-auto-detected-links *,
.aBn {
    border-bottom: 0 !important;
    cursor: default !important;
    color: inherit !important;
    text-decoration: none !important;
    font-size: inherit !important;
    font-family: inherit !important;
    font-weight: inherit !important;
    line-height: inherit !important;
}

/* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
.a6S {
    display: none !important;
    opacity: 0.01 !important;
}

/* What it does: Prevents Gmail from changing the text color in conversation threads. */
.im {
    color: inherit !important;
}

/* If the above doesn't work, add a .g-img class to any image in question. */
img.g-img + div {
    display: none !important;
}

/* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
/* Create one of these media queries for each additional viewport size you'd like to fix */

/* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
@media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
    u ~ div .email-container {
        min-width: 320px !important;
    }
}
/* iPhone 6, 6S, 7, 8, and X */
@media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
    u ~ div .email-container {
        min-width: 375px !important;
    }
}
/* iPhone 6+, 7+, and 8+ */
@media only screen and (min-device-width: 414px) {
    u ~ div .email-container {
        min-width: 414px !important;
    }
}


    </style>

    <!-- CSS Reset : END -->

    <!-- Progressive Enhancements : BEGIN -->
    <style>

	    .primary{
	background: #dd0a35;
}
.bg_white{
	background: rgba(19, 48, 41, 0.8);
}
.bg_light{
	background:rgba(12, 53, 47, 0.8);
}
.bg_black{
	background: #0e352b;
}
.bg_dark{
	background: rgba(19, 48, 41, 0.8);
}
.bg_darka{
	background: rgba(13, 66, 48, 0.8);
}
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(255,255,255,.5);
}

a{
	color: #62bdd8;
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {



}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr> 
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg); background-position: center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
            <td class='bg_dark email-section' style='text-align:center; padding-top: 5em;'>
                <div class='heading-section heading-section-white' style='background: #1412126b; padding: 30px; border-radius: 25px;'>
                    <span>Dear ".$email.",</span>
                    <!-- Simple animated GIF for email compatibility -->
                    <div style='margin: 20px 0;'>
                        <img src='https://media.giphy.com/media/26ufnwz3wDUli7GU0/giphy.gif' alt='Thank You' width='80' style='display:inline-block; border-radius:50%;'>
                    </div>
                    <h2 class='subheading'>Thank You for Your Patronage!</h2>
                    <p>
                        We sincerely appreciate your continued support and trust in Global Thrive Alliance.<br>
                        Your commitment helps us grow and serve you better. 
                    </p>
                    <p>
                        <h4>Your new bill for your next payment is as follows:</h4>
                        <strong>Contribution amount:</strong> <h3>".$amountcon."</h3>
                        <strong>Admin charge amount:</strong> <h3>".$adminfee."</h3>
                    </p>
                    <p>
                        <h2 class='subheading'>Current Balance</h2>
                        <strong>Balance:</strong> <h3>".$balance."</h3>
                        <strong>Last payment date:</strong> <h3>".$datebalanceu."</h3>
                    </p>
                    <!-- Encouragement section with another GIF -->
                    <div style='margin: 20px 0;'>
                        <img src='https://media.giphy.com/media/3o7aD2saalBwwftBIY/giphy.gif' alt='Keep Going' width='80' style='display:inline-block; border-radius:50%;'>
                    </div>
                    <p>
                        We encourage you to make your next payment on time to continue enjoying our services and benefits. Every payment you make brings us closer to our shared goals!
                    </p>
                   
                    
                    <p>
                        For more help please visit 
                        <a class='btn btn-primary' href='https://globalthrivealliance.com/help.html'>Help</a>.
                    </p>
                    <p>
                        If you have any questions or concerns, please contact us via email 
                        <a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a>
                        or call: <a href='tel:+234-9076-36728'>2349076367238</a>
                    </p>
                </div>
          </td>
        </tr><!-- end: tr -->
         <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
					  <tr>
						<td style='text-align: left; padding-right: 10px;'>
							<p>Contact us:<br> <span><a href='mailto:support@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
								         <a href='tel:2348069648432'>
                <span>+2348069648432</span>
              </a></span><br><a href='tel:+447479454857'>
                <span style='text-decoration: none;color: white;'>
                  +447479454857
                </span>
              </a></span><br>
			  <a href='https://wa.link/bc1z0r' target='_blank' >
            <img src='https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg' alt='WhatsApp' class='whatsapp-icon'>
        </a></p>
						</td>
					  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>");
} 
send_emailf($email, $conn);
            echo json_encode(["success" => true, "message" => "Thank you email sent"]);
            exit;

        case 'loandis':
            // Required: email, usercode, statuse, Loandaterepay, amountsent, amountint, Loandisdate, balance, amountcon
            $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $usercode = $_POST['usercode'] ?? '';
            $statuse = $_POST['statuse'] ?? '';
            $Loandaterepay = $_POST['Loandaterepay'] ?? '';
            $amountsent = $_POST['amountsent'] ?? '';
            $amountint = $_POST['amountint'] ?? '';
            $Loandisdate = $_POST['Loandisdate'] ?? '';
            $balance = $_POST['balance'] ?? '';
            $amountcon = $_POST['amountcon'] ?? '';

             function send_email($email){
      
       $email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
            $usercode = $_POST['usercode'] ?? '';
            $statuse = $_POST['statuse'] ?? '';
            $Loandaterepay = $_POST['Loandaterepay'] ?? '';
            $amountsent = $_POST['amountsent'] ?? '';
            $amountint = $_POST['amountint'] ?? '';
            $Loandisdate = $_POST['Loandisdate'] ?? '';
            $balance = $_POST['balance'] ?? '';
            $amountcon = $_POST['amountcon'] ?? '';
 
        //send email here
        send_mail($email,'Loan Approved',"<!DOCTYPE html>
<html lang='en' xmlns='http://www.w3.org/1999/xhtml' xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office'>
<head>
    <meta charset='utf-8'> <!-- utf-8 works for most cases -->
    <meta name='viewport' content='width=device-width'> <!-- Forcing initial-scale shouldn't be necessary -->
    <meta http-equiv='X-UA-Compatible' content='IE=edge'> <!-- Use the latest (edge) version of IE rendering engine -->
    <meta name='x-apple-disable-message-reformatting'>  <!-- Disable auto-scale in iOS 10 Mail entirely -->
    <title>Global Thrive Alliance; Loan Approved</title> <!-- The title tag shows in email notifications, like Android 4.4. -->

    <link href='https://fonts.googleapis.com/css?family=Work+Sans:200,300,400,500,600,700' rel='stylesheet'>

    <!-- CSS Reset : BEGIN -->
    <style>

        /* What it does: Remove spaces around the email design added by some email clients. */
        /* Beware: It can remove the padding / margin and add a background color to the compose a reply window. */
        html,
        body {
            margin: 0 auto !important;
            padding: 0 !important;
            height: 100% !important;
            width: 100% !important;
            background-color:rgb(19 43 38);
        }
        
        /* What it does: Stops email clients resizing small text. */
        * {
            -ms-text-size-adjust: 100%;
            -webkit-text-size-adjust: 100%;
        }
        
        /* What it does: Centers email on Android 4.4 */
        div[style*='margin: 16px 0'] {
            margin: 0 !important;
        }
        
        /* What it does: Stops Outlook from adding extra spacing to tables. */
        table,
        td {
            mso-table-lspace: 0pt !important;
            mso-table-rspace: 0pt !important;
        }
        
        /* What it does: Fixes webkit padding issue. */
        table {
            border-spacing: 0 !important;
            border-collapse: collapse !important;
            table-layout: fixed !important;
            margin: 0 auto !important;
        }
        
        /* What it does: Uses a better rendering method when resizing images in IE. */
        img {
            -ms-interpolation-mode:bicubic;
        }
        
        /* What it does: Prevents Windows 10 Mail from underlining links despite inline CSS. Styles for underlined links should be inline. */
        a {
            text-decoration: none;
        }
        
        /* What it does: A work-around for email clients meddling in triggered links. */
        *[x-apple-data-detectors],  /* iOS */
        .unstyle-auto-detected-links *,
        .aBn {
            border-bottom: 0 !important;
            cursor: default !important;
            color: inherit !important;
            text-decoration: none !important;
            font-size: inherit !important;
            font-family: inherit !important;
            font-weight: inherit !important;
            line-height: inherit !important;
        }
        
        /* What it does: Prevents Gmail from displaying a download button on large, non-linked images. */
        .a6S {
            display: none !important;
            opacity: 0.01 !important;
        }
        
        /* What it does: Prevents Gmail from changing the text color in conversation threads. */
        .im {
            color: inherit !important;
        }
        
        /* If the above doesn't work, add a .g-img class to any image in question. */
        img.g-img + div {
            display: none !important;
        }
        
        /* What it does: Removes right gutter in Gmail iOS app: https://github.com/TedGoas/Cerberus/issues/89  */
        /* Create one of these media queries for each additional viewport size you'd like to fix */
        
        /* iPhone 4, 4S, 5, 5S, 5C, and 5SE */
        @media only screen and (min-device-width: 320px) and (max-device-width: 374px) {
            u ~ div .email-container {
                min-width: 320px !important;
            }
        }
        /* iPhone 6, 6S, 7, 8, and X */
        @media only screen and (min-device-width: 375px) and (max-device-width: 413px) {
            u ~ div .email-container {
                min-width: 375px !important;
            }
        }
        /* iPhone 6+, 7+, and 8+ */
        @media only screen and (min-device-width: 414px) {
            u ~ div .email-container {
                min-width: 414px !important;
            }
        }
        
        
            </style>
        
            <!-- CSS Reset : END -->
        
            <!-- Progressive Enhancements : BEGIN -->
            <style>
        
                .primary{
            background: #dd0a35;
        }
        .bg_white{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_light{
            background:rgba(12, 50, 65, 0.8);
        }
        .bg_black{
            background: #0e2535;
        }
        .bg_dark{
            background: rgba(19, 48, 41, 0.8);
        }
        .bg_darka{
            background: rgba(12, 50, 65, 0.8);
        }
.email-section{
	padding:2.5em;
}

/*BUTTON*/
.btn{
	padding: 5px 15px;
	display: inline-block;
}
.btn.btn-primary{
	border-radius: 30px;
	background: #055541;
	color: #ffffff;
}
.btn.btn-white{
	border-radius: 30px;
	background: #ffffff;
	color: #000000;
}
.btn.btn-white-outline{
	border-radius: 30px;
	background: transparent;
	border: 1px solid #fff;
	color: #fff;
}

h1,h2,h3,h4,h5,h6{
	font-family: 'Work Sans', sans-serif;
	margin-top: 0;
	font-weight: normal;
	color: rgba(255,255,255,.9);
}

body{
	font-family: 'Work Sans', sans-serif;
	font-weight: 400;
	font-size: 15px;
	line-height: 1.8;
	color: rgba(12, 52, 105, 0.5);
}

a{
	color:rgb(70, 78, 116);
}

/*LOGO*/

.logo{
	margin: 0;
	display: inline-block;
	position: absolute;
	top: 10px;
	left: 0;
	right: 0;
	margin-bottom: 0;
}

.logo a{
	color: #fff;
	font-size: 24px;
	font-weight: 700;
	text-transform: uppercase;
	font-family: 'Work Sans', sans-serif;
	display: inline-block;
	border: 2px solid #fff;
	line-height: 1.3;
	padding: 10px 15px 4px 15px;
	margin: 0;
}
.logo h1 a span{
	line-height: 1;
}

.navigation{
	padding: 0;
}
.navigation li{
	list-style: none;
	display: inline-block;;
	margin-left: 5px;
	font-size: 13px;
	font-weight: 500;
}
.navigation li a{
	color: rgba(0,0,0,.4);
}

/*HERO*/
.hero{
	position: relative;
	z-index: 0;
}

.hero .overlay{
	position: absolute;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	content: '';
	width: 100%;
	background: #000;
	z-index: -1;
	opacity: .3;
}

.hero .text{
	color: rgba(255,255,255,.9);
}
.hero .text h2{
	color: #fff;
	font-size: 40px;
	margin-bottom: 20px;
	font-weight: 300;
	line-height: 1.3;
	/*text-transform: uppercase;*/
}
.hero .text .icon{
	position: absolute;
	bottom: -30px;
	left: 0;
	right: 0;
}


/*HEADING SECTION*/
.heading-section h2{
	color: rgba(255,255,255,.9);
	font-size: 28px;
	margin-top: 0;
	line-height: 1.4;
	font-weight: 400;
	text-transform: uppercase;
	letter-spacing: 1px;
}
.heading-section .subheading{
	margin-bottom: 20px !important;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
	position: relative;
}
.heading-section .subheading::after{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -5px;
	content: '';
	width: 100%;
	height: 2px;
	background: #040653;
	margin: 0 auto;
}
.heading-section .subheading::before{
	position: absolute;
	left: 0;
	right: 0;
	bottom: -10px;
	content: '';
	width: 70%;
	height: 2px;
	background: #055044;
	margin: 0 auto;
}

.heading-section-white{
	color: rgba(255,255,255,.8);
}
.heading-section-white h2{
	line-height: 1;
	padding-bottom: 0;
}
.heading-section-white h2{
	color: #ffffff;
}
.heading-section-white .subheading{
	margin-bottom: 0;
	display: inline-block;
	font-size: 13px;
	text-transform: uppercase;
	letter-spacing: 2px;
	color: rgba(255,255,255,.4);
}


/*TRAINER*/
.trainer h2{
	margin-bottom: 5px;
}
.trainer span{
	text-transform: uppercase;
	color: rgba(255,255,255,.2);
}

/*PROGRAM*/
.text-program .price{
	font-size: 20px;
	margin-bottom: 0;
	color: #140a4f;
}
.text-program h2{
	font-size: 18px;
	margin-bottom: 10px;
	font-weight: 500;
}
.text-program p{
	margin-top: 0;
}

/*FOOTER*/

.footer{
	color: rgba(255,255,255,.5);

}
.footer .heading{
	color: #ffffff;
	font-size: 20px;
}
.footer ul{
	margin: 0;
	padding: 0;
}
.footer ul li{
	list-style: none;
	margin-bottom: 10px;
}
.footer ul li a{
	color: rgba(255,255,255,1);
}


@media screen and (max-width: 500px) {


}


    </style>


</head>

<body width='100%' style='margin: 0; padding: 0 !important; mso-line-height-rule: exactly; background-color: #222222;'>
	<center style='width: 100%; background-color: #040404;'>
    <div style='display: none; font-size: 1px;max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; mso-hide: all; font-family: sans-serif;'>
      &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
    </div>
    <div style='max-width: 600px; margin: 0 auto;' class='email-container'>
    	<!-- BEGIN BODY -->
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
	    <tr>
			<td valign='middle' class='hero bg_black' style='text-align: center;justify-items: center;'>
				<h6 class='subheading' style='margin: 0;'>GTA</h6>
			</td>
		 </tr>  
		<tr>
          <td valign='middle' class='hero bg_white' style='background-image: url(https://globalthrivealliance.com/images/Rectangle.jpg); background-position:center; background-size: cover; height: 300px;border-radius: 25px;'>
          	<div class='overlay'></div>
            <table>
            	<tr>
            		<td>
            			<div class='text' style='padding: 0 4em; text-align: center;'>
            				<div class='icon'>
			        				<a href='#'>
			                  <img src='https://globalthrivealliance.com/images/service-icon-02.png' alt='' style='width: 60px; max-width: 600px; height: auto; margin: auto; display: block;'>
			                </a>
			              </div>
            			</div>
            		</td>
            	</tr>
            </table>
          </td>
	      </tr><!-- end tr -->
	      <tr>
          <td class='bg_darka email-section' style='text-align:center; padding-top: 5em;'>
          	<div class='heading-section heading-section-white' style='    background: #1412126b;
			  padding: 30px;
			  border-radius: 25px;'>
          		<span class='subheading'>Loan sent</span>
            	<p><h2>Dear user</h2><br>
				<p><h4>Your loan application was successful and ".$amountsent." disbured to the accont submitted.</h4><h5>You are to payback before ".$Loandaterepay."</h5><br><h5>Your monthly interest payment is ".$amountint."</h5>
				<h1 class='subheading' style='font-size:xx-large ;'>".$balance."</h1>
                <h6>Above is the tatal amount plus interest to be paid back.</h6</p></p>
				<p><a href='https://globalthrivealliance.com/auth/login' class='btn btn-primary'>Login</a></p>
            	</div>
          </td>
        </tr><!-- end: tr -->
          <tr>
	        <td class='bg_dark email-section'>
	        	<div class='heading-section' style='text-align: center; padding: 0 30px;'>
	        		
	          	<h3 class='subheading'>Please note:</h3>
	        	</div>
	        	<table role='presentation' border='0' cellpadding='0' cellspacing='0' width='100%'>
	        		
              <tr>
          			<td style='padding-bottom: 30px;'>
          				<table role='presentation' border='0' cellpadding='0' cellspacing='0' width='100%'>
          					<tr valign='middle' width='50%'>
		                  <img src='https://globalthrivealliance.com/images/about-img.png' alt='' style='width: 100%; border-radius: 25px; max-width: 600px; height: auto; margin: auto; display: block;'>
		                </tr>
		                <tr valign='middle' width='50%'>
		                  <div class='text-program' style='text-align: left; padding-left:25px;'>
		                  	<p class='meta'><span>your loan was sent on: </span> <span>".$Loandisdate."</span></p>
                              <p class='meta'><span>you are to pay pack before: </span> <span>".$Loandaterepay."</span></p> 
				              	<h2>Loan information</h2>
				              	<p>Please do note that your loaned amount is (".$amountsent.").Amount to be returned is (".$balance.") <br> for more information do go through our <a href='https://globalthrivealliance.com'>loan T&C</a> </p>
				              	<p><a href='https://globalthrivealliance.com' class='btn btn-primary'>Read more</a></p>
		                  </div>
		                </tr>
          				</table>
          			</td>
              </tr>
          	</table>
          </td>
        </tr> <!-- end: tr -->
      <!-- 1 Column Text + Button : END -->
      </table>
      <table align='center' role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='margin: auto;'>
        <tr>
        	<td valign='middle' class='bg_black footer email-section'>
        		<table>
            	<tr>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: left; padding-right: 10px;'>
                      	<p>&copy; 2025 GLOBAL THRIVE ALLIANCE.<br> Design by <span>LOVE BARI</span></p>
                      </td>
                    </tr>
                  </table>
                </td>
                <td valign='top' width='33.333%'>
                  <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
                    <tr>
                      <td style='text-align: right; padding-left: 5px; padding-right: 5px;'>
                      	<p><a href='#' style='color: rgba(255,255,255,.4);'>Unsubcribe</a></p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
			  <tr>
				<td valign='top' width='80%'>
					<table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%'>
						<tr>
							<td style='text-align: left; padding-right: 10px;'>
								<p>Contact us:<br> <span><a href='mailto:contact@globalthrivealliance.com'>contact@globalthrivealliance.com</a><br>
									<a href='tel:+234-9076-36728'>2349076367238</a></span></p>
							</td>
						  </tr>
					</table>
				  </td>
			  </tr>
            </table>
        	</td>
        </tr>
      </table>

    </div>
  </center>
</body>
</html>" );
    }
   
    send_email($email);

            echo json_encode(["success" => true, "message" => "Loan disbursement email sent"]);
            exit;

        default:
            send_error("Unknown action");
    }
}

send_error("Invalid request", 405);


   

?>