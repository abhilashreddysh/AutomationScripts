let stats = document.getElementsByClassName("status");

for (const tdstatus of stats) {
  if (tdstatus.outerText === "ACTIVE") {
    tdstatus.id = "status-active";
  } else {
    tdstatus.id = "status-inactive";
  }
}

let stats = document.getElementsByClassName("status");

for (const tdstatus of stats) {
  if (tdstatus.outerText === "ACTIVE") {
    tdstatus.id = "status-active";
  } else {
    tdstatus.id = "status-inactive";
  }
}
