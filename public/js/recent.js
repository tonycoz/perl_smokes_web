function match_regexp(value, search_text) {
    var invert = 0;
    var re_text  = search_text.replace(/^!/, "");
    invert = re_text != search_text;
    try {
	var re = new RegExp(re_text, "i");
	return value.match(re);
    }
    catch (err) {
	return false;
    }
}

window.addEventListener("load", (event) => {
    var status_in = document.getElementById("status");
    var os_in = document.getElementById("os");
    var arch_in = document.getElementById("arch");
    var cc_in = document.getElementById("cc");
    var from_in = document.getElementById("from");
    var reports = document.getElementById("commits")
	.getElementsByClassName("smoke");
    var do_search = function (e) {
	var status = status_in.value;
	var os = os_in.value;
	var arch = arch_in.value;
	var cc = cc_in.value;
	var from = from_in.value;
	for (var tr of reports) {
	    var ok = 1;

	    var cols = tr.getElementsByTagName("td");
	    if (status != "") {
		ok = match_regexp(cols[0].textContent, status);
	    }
	    if (os != "" && ok) {
		ok = match_regexp(cols[3].textContent, os);
	    }
	    if (arch != "" && ok) {
		ok = match_regexp(cols[4].textContent, arch);
	    }
	    if (cc != "" && ok) {
		var sp = cols[4].getElementsByTagName("span");
		var cc_text = sp.length ? sp[0].title : cols[5].textContent;
		ok = match_regexp(cc_text, cc);
	    }
	    if (from != "" && ok) {
		ok = match_regexp(cols[6].textContent, from);
	    }

	    if (ok) {
		tr.classList.remove("hide");
	    }
	    else {
		tr.classList.add("hide");
	    }
	}
    };
    status_in.addEventListener("input", do_search);
    os_in.addEventListener("input", do_search);
    arch_in.addEventListener("input", do_search);
    cc_in.addEventListener("input", do_search);
    from_in.addEventListener("input", do_search);
    document.getElementById("filters").addEventListener("reset", (e) => {
	setTimeout((e) => {
	    do_search(e);
	}, 0);
    });
});
