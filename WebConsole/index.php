<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <!-- <meta name="viewport" content="width=1024"> -->
    <link rel="stylesheet" href="/styles/style.css">
    <title>[hound] <?php echo strtoupper(basename(dirname(__FILE__))); ?></title>
  </head>
  <body>
    <?php
    $currentdir = getcwd();
    $env = strtolower(basename(dirname(__FILE__)));
    $port=443;
    if ($env == "webconsole"){
      $port=80;
    }
    ?>
    <div class="container">
      <h1><a href="http://10.1.1.11:<?php echo $port?>/index.php">Hound <?php echo basename(dirname(__FILE__)); ?> Environment</a></h1>
      <!-- <h3><a href="https://stackexchange.com/users/28886743"><img src="https://stackexchange.com/users/flair/28886743.png" width="208" height="58" alt="profile for Abhilash Reddy on Stack Exchange, a network of free, community-driven Q&amp;A sites" title="profile for Abhilash Reddy on Stack Exchange, a network of free, community-driven Q&amp;A sites"></a></h3> -->
      <div class="main-card">
        <div class="cards">
          <p class="card-header">Server Stats</p><br>
          <table>
            <thead>
              <tr>
                <th>Service</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>CPU Temperature</td>
                <td class="status" style="color:#ffd97d;"><?php
                  $output = shell_exec("$currentdir/bashScripts/cputemperature.sh");
                  echo "$output&degC";
                  ?></td>
                <td>-</td>
              </tr>
              <tr>
                <td>samba-d</td>
                <td class="status"><?php
                  echo shell_exec("$currentdir/bashScripts/servicestatus.sh smbd");
                  ?></td>
                <td><a class="t-btn" href="?smbd=true">restart</a></td>
              </tr>
              <tr>
                <td>ssh-d</td>
                <td class="status"><?php
                  echo shell_exec("$currentdir/bashScripts/servicestatus.sh sshd");
                  ?></td>
                <td><a class="t-btn" href="?sshd=true">restart</a></td>
              </tr>
              <tr>
                <td>Transmission-d</td>
                <td class="status"><?php
                  echo shell_exec("$currentdir/bashScripts/servicestatus.sh transmission-daemon");
                  ?></td>
                <td><a class="t-btn" href="?transmissiond=true">restart</a></td>
              </tr>
              <tr>
                <td>Transmission-telegram-d</td>
                <td class="status"><?php
                  echo shell_exec("$currentdir/bashScripts/servicestatus.sh transmission-telegram-d");
                  ?></td>
                <td><a class="t-btn" href="?transmissiontelegramd=true">restart</a></td>
              </tr>
              <tr>
                <td>Nginx</td>
                <td class="status"><?php
                  echo shell_exec("$currentdir/bashScripts/servicestatus.sh nginx");
                  ?></td>
                <td><a class="t-btn" href="?nginx=true">restart</a></td>
              </tr>
              <tr>
                <td>Firewall-ufw</td>
                <td class="status"><?php
                  echo shell_exec("sudo ufw status | head -n 1 | awk -F ' ' '{print $2}'");
                  ?></td>
                <td>-</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="cards">
          <p class="card-header">Quick Actions</p><br>
          <div class="btn-cont">
            <!-- This link will add ?test=true to your URL, myfilename.php?test=true -->
            <!-- <a class="btn" href="?readonly=true">Read Only</a> -->
            <!-- <a class="btn" href="?edit=true">edit Access</a> -->
            <!-- <a class="btn" href="?nginx=true">Nginx restart</a> -->
            <a class="btn" href="http://192.168.1.11:9091/transmission/web/">Transmission</a>
            <a class="btn" href="http://192.168.1.11:443">Zabbix</a>
          </div>
        </div>
        <div class="cards">
          <p class="card-header">Disk Info</p><br>
          <?php
          $output = shell_exec("$currentdir/bashScripts/diskinfo.sh");
          echo "<pre>$output</pre>";
          ?>
        </div>
        <div class="cards">
          <p class="card-header">Disk Info</p><br>
          <?php
          $output = shell_exec('df -Ph');
          echo "<pre>$output</pre>";
          ?>
        </div>
        <div class="cards">
          <p class="card-header">Memory</p><br>
          <br>
          <?php
          $output = shell_exec('free -h');
          echo "<pre>$output</pre>";
          ?>
        </div>
        <div class="cards">
          <p class="card-header">Logged in users</p><br>
          <br>
          <?php
          $output = shell_exec('w');
          echo "<pre>$output</pre>";
          ?>
        </div>
      </div>
    </div>
  </body>
  <script src="/js/main.js"></script>
</html>
<?php
if ($_GET['readonly']) {
  # This code will run if ?test=true is set.
  shell_exec("$currentdir/bashScripts/blockedit.sh $env");
  // header("Location: http://10.1.1.11:$port/index.php?success=true");
}
if ($_GET['edit']) {
  shell_exec("$currentdir/bashScripts/editable.sh $env");
}
if ($_GET['nginx']) {
  shell_exec("$currentdir/bashScripts/cycleservice.sh nginx");
}
if ($_GET['sshd']) {
  shell_exec("$currentdir/bashScripts/cycleservice.sh sshd");
}
if ($_GET['smbd']) {
  shell_exec("$currentdir/bashScripts/cycleservice.sh smbd");
}
if ($_GET['transmissiond']) {
  shell_exec("$currentdir/bashScripts/cycleservice.sh transmission-daemon");
}
if ($_GET['transmissiontelegramd']) {
  shell_exec("$currentdir/bashScripts/cycleservice.sh transmission-telegram-d");
}
?>