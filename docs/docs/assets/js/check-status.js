document.addEventListener("DOMContentLoaded", function () {
  const rows = document.querySelectorAll("table tr");
  rows.forEach((row) => {
    const link = row.querySelector("td a");
    if (link) {
      const url = link.href;
      fetch(url, { method: "HEAD", mode: "no-cors" })
        .then((response) => {
          // If no-cors, you can't read status; assume reachable
          row.classList.add("reachable");
        })
        .catch((error) => {
          row.classList.add("unreachable");
        });
    }
  });
});
