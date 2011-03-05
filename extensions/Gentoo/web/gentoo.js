function add_arches_edit() {
    var i;

    for(i=0;i<document.changeform.addarches.options.length;i++) {
        if(document.changeform.addarches.options[i].selected) {
            if(!document.changeform.newcc.value) {
                document.changeform.newcc.value = document.changeform.addarches.options[i].value;
            } else {
                document.changeform.newcc.value = document.changeform.newcc.value + "," + document.changeform.addarches.options[i].value;
            }
            // Deselect the item...not necessary
            document.changeform.addarches.options[i].selected = false;
        }
    }
}

function add_arches_create() {
    var i;

    for(i=0;i<document.Create.addarches.options.length;i++) {
        if(document.Create.addarches.options[i].selected) {
            if(!document.Create.cc.value) {
                document.Create.cc.value = document.Create.addarches.options[i].value;
            } else {
                document.Create.cc.value = document.Create.cc.value + "," + document.Create.addarches.options[i].value;
            }
            // Deselect the item...not necessary
            document.Create.addarches.options[i].selected = false;
        }
    }
}