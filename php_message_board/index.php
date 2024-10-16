<?php
if ($_SERVER['REQUEST_METHOD'] == 'POST' && !empty($_POST['message'])) {
    $message = htmlspecialchars($_POST['message']);
    file_put_contents('messages.txt', $message . "\n", FILE_APPEND);
}
$messages = file_exists('messages.txt') ? file('messages.txt', FILE_IGNORE_NEW_LINES) : [];
?>
<!DOCTYPE html>
<html lang="en">
<head><title>PHP Message Board</title></head>
<body>
    <h1>Message Board</h1>
    <form method="post">
        <textarea name="message" rows="4" cols="50"></textarea><br>
        <button type="submit">Post Message</button>
    </form>
    <ul><?php foreach ($messages as $msg): ?><li><?= $msg ?></li><?php endforeach; ?></ul>
</body></html>
