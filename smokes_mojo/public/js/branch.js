window.addEventListener("load", (event) => {
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
