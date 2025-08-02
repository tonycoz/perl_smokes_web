Array.from(document.getElementsByClassName("autocomplete"))
    .forEach((element) => {
	let last = element.value;
	let vals = [];
	const vals_ele = document.getElementById(element.name + "-values");
	element.addEventListener("input", (e) => {
	    if (last != e.target.value) {
		
	    }
	});
    });
