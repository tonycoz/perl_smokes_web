window.addEventListener("load", (event) => {
    var copy_buttons = document.getElementsByClassName("copycommit");
    for (var button of copy_buttons) {
	button.addEventListener("click", (event) => {
	    var target = event.currentTarget;
	    var sha = target.dataset["sha"];
	    navigator.clipboard.writeText(sha);
	    target.classList.add("highlight");
	    setTimeout(() => {
		target.classList.remove("highlight");
	    }, 500);
	});
    }
});
