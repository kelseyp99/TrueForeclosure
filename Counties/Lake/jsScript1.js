function() {
  var element = document.querySelector('[ng-click="toggleSearch(\'case\')"]');
  if (element) {
    element.selectedIndex = 2;
    var evt = new Event('change');
    element.dispatchEvent(evt);
  } else {
    console.log('Element not found.');
  }
}
