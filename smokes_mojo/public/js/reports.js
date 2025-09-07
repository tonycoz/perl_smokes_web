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
    var reports = document.getElementById("commits")
	.getElementsByClassName("smoke");
    var search_params = [ "status", "os", "arch", "cc", "from" ];
    var search_cols =
	{
	    status: 0,
	    os: 1,
	    arch: 2,
	    cc: 3,
	    from: 4
	};
    var do_search = function () {
	// mirror the filter parameters in the URL fragment
	var frag_obj = new URLSearchParams();
	search_params.forEach((name) => {
	    var val = document.getElementById(name).value;
	    if (val != "")
		frag_obj.set(name, val);
	});
	var frag = frag_obj.toString();
	if (frag != "") {
	    location.hash = frag;
	}
	else {
	    // avoids a bare #
	    history.pushState("", document.title,
			      location.pathname + location.search);
	}
	
	var values = {};
	search_params.forEach((name) => {
	    values[name] = document.getElementById(name).value;
	});
	var match_names = search_params.filter(name => values[name] != "");
	for (var tr of reports) {
	    var cols = tr.getElementsByTagName("td");
	    var ok = match_names.every((name) => {
		var content = cols[search_cols[name]].textContent;
		return match_regexp(content, values[name]);
	    });

	    if (ok) {
		tr.classList.remove("hide");
	    }
	    else {
		tr.classList.add("hide");
	    }
	}
    };
    var start = new URLSearchParams(location.hash.substring(1));
    search_params.forEach((name) => {
	var ele = document.getElementById(name);
	if (start.has(name)) {
	    ele.value = start.get(name);
	}
	ele.addEventListener("input", do_search);
    });
    do_search();
    document.getElementById("filters").addEventListener("reset", (e) => {
	setTimeout((e) => {
	    do_search(e);
	}, 0);
    });

    var bre = document.getElementById("b");
    var orig_branch = bre.value;
    b.addEventListener("change", (ev) => {
	var s = ev.target;
	if (s.value == "") {
	    s.options.length = 0;
	    var branches = Array.from(document.getElementById("branches").options);
	    branches.forEach((opt) => {
		var opt_value = opt.value;
		var sopt = document.createElement("option");
		sopt.value = opt.value;
		sopt.innerText = opt.value;
		if (opt.value == orig_branch) {
		    sopt.selected = 1;
		}
		s.appendChild(sopt);
	    });
	}
	else {
	    s.form.submit();
	}
    });
});
