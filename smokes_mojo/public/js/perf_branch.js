import ttest2 from 'https://cdn.jsdelivr.net/gh/stdlib-js/stats-ttest2@esm/index.mjs';

function stats(numbers) {
    const sorted = Array.from(numbers).sort((a, b) => a - b);
    const middle = Math.floor(sorted.length / 2);

    var stats = {};

    if (sorted.length % 2 === 0) {
        stats.median = (sorted[middle - 1] + sorted[middle]) / 2;
    }
    else {
	stats.median = sorted[middle];
    }
    stats.min = sorted[0];
    stats.max = sorted[sorted.length - 1];
    stats.mean = sorted.reduce((a, b) => a + b) / sorted.length;
    // FIXME: should depend on array size
    //stats.clean = sorted.slice(5, sorted.length - 5);
    stats.clean = numbers;
    stats.cleanmean = stats.clean.reduce((a, b) => a + b) / stats.clean.length;

    return stats;
}

function stats_diff (stat1, stat0, iter) {
    return {
	median: (stat1.median - stat0.median)/iter,
	min: (stat1.min - stat0.min)/iter,
	max: (stat1.max - stat0.max)/iter,
	mean: (stat1.mean - stat0.mean)/iter,
	cleanmean: (stat1.cleanmean - stat0.cleanmean)/iter
    };
}

function summarize(data, measure) {
    // task-clock is the main measure
    var results = data.benchmark.results;
    var summary = {};
    for (var bench in results) {
	var check = results[bench];
	var result0 = stats(check.result0[measure]);
	var result1 = stats(check.result1[measure]);
	check.summary = stats_diff(result1, result0, check.iterations);
	//check.result = check.result1[measure].map(n => n-result0.mean);
	check.result = result1.clean.map(a => (a-result0.cleanmean)/check.iterations);
	check.resultmean = check.result.reduce((a, b) => a + b) / check.result.length;
	check.resultstddev = Math.sqrt(check.result.reduce((a, b) => a + (b-check.resultmean) * (b-check.resultmean)) / check.result.length);
    }
}

function analyze(configs, commits) {
    var p = parseFloat(document.getElementById("p").value);
    console.log(`p value ${p}`);
    var r_ele = document.getElementById("special");
    var interesting = [];
    for (var cfg in configs) {
	var have_config = commits.filter((c) => c.repsnamed[cfg]);
	var last;
	r_ele.innerHTML = '<tr><th>config</th><th>benchmark</th><th>statistic</th><th>xmean</th><th>ymean</th><th>ci0</th><th>ci1</th><th>nullValue</th><th>%diff</th></tr>';
	have_config.forEach(c => {
	    var ctr = document.createElement("tr");
	    var ctd = document.createElement("td");
	    ctd.colSpan = 9;
	    ctd.innerText =`commit ${c.subject}`;
	    ctr.appendChild(ctd);
	    r_ele.appendChild(ctr);
	    if (last) {
		var creport = c.repsnamed[cfg].data.benchmark.results;
		var lastreport = last.repsnamed[cfg].data.benchmark.results;
		for (var benchname in lastreport) {
		    var cbench = creport[benchname];
		    var lastbench = lastreport[benchname];
		    var out = ttest2(
			lastbench.result,
			cbench.result, {
			    'alpha': p
			});
		    var pc = Math.abs((out.ymean - out.xmean) / out.xmean) * 100;
		    if (out.rejected && pc > 5) {
			var tr = document.createElement("tr");
			// ${c.sha} ${last.sha} ${lastbench.resultmean} ${cbench.resultmean} lastbench.resultstddev, cbench.resultstddev}
			var row = [ out.xmean, out.ymean, out.ci[0], out.ci[1],
				    out.nullValue, pc,
				    // lastbench.resultstddev, cbench.resultstddev
				  ].map(n => Math.round(n));
			row.unshift(cfg, benchname, Math.round(out.statistic * 100) / 100);
			var td = document.createElement("td");
			row.forEach((item) => {
			    var td = document.createElement("td");
			    td.innerText = item;
			    tr.appendChild(td);
			});
			//div.innerText = `found ${cfg}:${benchname} ${out.statistic} ${out.xmean} ${out.ymean} ${lastbench.resultstddev} ${cbench.resultstddev} ${out.ci[0]} ${out.ci[1]} ${out.nullValue} ${pc}`;
			r_ele.appendChild(tr);
			//console.log(lastbench.result.join(' '));
			//console.log(cbench.result.join(' '));
		    }
		    else {
			console.log(`unfound ${c.sha} ${last.sha} ${cfg}:${benchname} ${lastbench.resultmean} ${cbench.resultmean}`);
		    }
		}
	    }
	    last = c;
	});
    }
}

function populate_chart(ele, commits, configs) {
    const labels = commits.map((c) => c.subject);
    var data = {
	labels: labels,
	datasets: [],
    };
    var datasets = {};
    commits.forEach((c) => {
	c.reports.forEach((r) => {
	    if (!datasets[r.config_name]) {
		datasets[r.config_name] = {
		    label: r.config_name,
		    data: [],
		};
	    }
	    //datasets[r.config_name].data.push({
	});
    });
}

window.addEventListener("load", (event) => {
    var commits = JSON.parse(document.getElementById("commitdata").innerHTML);
    var urls = [];
    var state_ele = document.getElementById("status");
    var chart_ele = document.getElementById("chart");
    var loaded = 0;
    var total = 0;
    var configs = {};
    var measure = "task-clock";
    commits.forEach((commit) => {
	commit.repsnamed = {};
	commit.reports.forEach((report) => {
	    ++total;
	    configs[report.config_name] = 1;
	    urls.push(report.url);
	    fetch(report.url, {
		headers: {
		    "Accept": "application/json"
		}
	    })
            .then((result) => result.json())
            .then((data) => {
	        ++loaded;
		commit.repsnamed[report.config_name] = report;
		report.data = data;
		report.summary = summarize(data, measure);
		if (loaded == total) {
		    state_ele.innerText = `Finished loading ${total} reports, analyzing data, don't hold your breath`;
		    analyze(configs, commits);
		    //populate_chart(chart_ele, commits, configs);
		}
		else {
		    state_ele.innerText = `Loaded ${loaded} of ${total} reports`;
		}
	    });
	});
    });
    if (total == 0) {
	state_ele.innerText = `No reports found`;
    }
});
