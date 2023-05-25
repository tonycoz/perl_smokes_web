window.addEventListener("load", (event) => {
    var pre = document.getElementById("dblog");
    pre.textContent = "Loading...";
    var req = new XMLHttpRequest();
    req.addEventListener("readystatechange", (e) => {
	if (req.readyState === XMLHttpRequest.DONE) {
	    const status = req.status;
	    if (status === 0 || (status >= 200 && status < 400)) {
		pre.textContent = req.responseText;
	    }
	    else {
		pre.textContent = req.statusText;
	    }
	}
    });
    req.open("GET", pre.dataset.rawurl);
    req.send();
});
