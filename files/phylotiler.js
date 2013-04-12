function initialize() {

	var imageTypeOptions = {
		getTileUrl: function(coord, zoom) {
				var normalizedCoord = getNormalizedCoord(coord, zoom);
				if (!normalizedCoord) {
					return null;
				}
				var bound = Math.pow(2, zoom);
				return  "tiles/" + zoom + "/" + normalizedCoord.x + "-" + (normalizedCoord.y) + ".jpg";

		},
	
		tileSize: new google.maps.Size(256, 256),
			maxZoom: maxzoom,
			minZoom: minzoom,
			radius: 1738000,
			name: "Tree"
	};
	
	var imageMapType = new google.maps.ImageMapType(imageTypeOptions);			
	
	var myLatlng = new google.maps.LatLng(0, 0);
 	
	var myOptions = {
		center: myLatlng,
		zoom: 0,
		streetViewControl: false,
		mapTypeControlOptions: {
			mapTypeIds: ["Tree"]
		},
		backgroundColor: "#000000"
	};
					
	var map = new google.maps.Map(document.getElementById("map_canvas"), myOptions);
	map.mapTypes.set('tree', imageMapType);
	map.setMapTypeId('tree');
    
/*	if (imagetype == 'SVG') {
		var xmlhttp = new XMLHttpRequest();
	     xmlhttp.open("GET", "tree.svg", false);
	     xmlhttp.send();
	     
	
	     var overlay = new SVGOverlay({ 
	       content: xmlhttp.responseText,
	       map: map 
	     });
	
	     var svg = overlay.getSVG();
	
	     svg.setAttribute("opacity", 0.5);
	}*/
	
	function bound(value, opt_min, opt_max) {
		if (opt_min != null) value = Math.max(value, opt_min);
	    if (opt_max != null) value = Math.min(value, opt_max);
		return value;
	}

	function degreesToRadians(deg) {
		return deg * (Math.PI / 180);
	}

	function radiansToDegrees(rad) {
		return rad / (Math.PI / 180);
	}

	function MercatorProjection() {
		this.pixelOrigin_ = new google.maps.Point(treesize / 2, treesize / 2);
		this.pixelsPerLonDegree_ = treesize / 360;
		this.pixelsPerLonRadian_ = treesize / (2 * Math.PI);
	}

	MercatorProjection.prototype.fromLatLngToPoint = function(latLng, opt_point) {
		var me = this;
		var point = opt_point || new google.maps.Point(0, 0);
		var origin = me.pixelOrigin_;
		
		point.x = origin.x + latLng.lng() * me.pixelsPerLonDegree_;

		// NOTE(appleton): Truncating to 0.9999 effectively limits latitude to
		// 89.189.  This is about a third of a tile past the edge of the world
		 // tile.
		var siny = bound(Math.sin(degreesToRadians(latLng.lat())), -0.9999, 0.9999);
		point.y = origin.y + 0.5 * Math.log((1 + siny) / (1 - siny)) * -me.pixelsPerLonRadian_;
		return point;
	};

	MercatorProjection.prototype.fromPointToLatLng = function(point) {
		var me = this;
		var origin = me.pixelOrigin_;
		var lng = (point.x - origin.x) / me.pixelsPerLonDegree_;
		var latRadians = (point.y - origin.y) / -me.pixelsPerLonRadian_;
		var lat = radiansToDegrees(2 * Math.atan(Math.exp(latRadians)) - Math.PI / 2);
		 return new google.maps.LatLng(lat, lng);
	};

	// Wait for idle map
	var projection = new MercatorProjection();
					
	
	for (var i = 0; i < nodedata.markers.length; i++) {
		var bubblecontent = '';
		if (! nodedata.markers[i].image == '') {
			bubblecontent += '<img src="'+nodedata.markers[i].image+'" style="float: left;" width="50"  />';
		}
		if (! nodedata.markers[i].content == '') {
			bubblecontent += ''+nodedata.markers[i].content+'';
		}
		if (! nodedata.markers[i].link == '') {
			bubblecontent += '<br /><a href="'+nodedata.markers[i].link+'" target="_blank"/>More...</a>';
		}
		var marker = new google.maps.Marker({
			position: projection.fromPointToLatLng(
			   new google.maps.Point(nodedata.markers[i].x, nodedata.markers[i].y)
			),
			map: map,
			title:"Marker",
			content: bubblecontent
		});
				
		var infoWindow = new google.maps.InfoWindow();
						            
		google.maps.event.addListener(marker, 'click', function () {
			infoWindow.setContent(this.content);
			infoWindow.open(map, this);
	    });
	}
					
    google.maps.event.addListener(map, 'center_changed', function() {
		checkBounds();
	});

	var allowedBounds = new google.maps.LatLngBounds(
		projection.fromPointToLatLng(new google.maps.Point(0, treesize)),
		projection.fromPointToLatLng(new google.maps.Point(treesize, 0))        
   );

      function checkBounds() {
        if(allowedBounds.contains(map.getCenter())) {
          return;
        }
        var mapCenter = map.getCenter();
        var X = mapCenter.lng();
        var Y = mapCenter.lat();

        var AmaxX = allowedBounds.getNorthEast().lng();
        var AmaxY = allowedBounds.getNorthEast().lat();
        var AminX = allowedBounds.getSouthWest().lng();
        var AminY = allowedBounds.getSouthWest().lat();

        if (X < AminX) {X = AminX;}
        if (X > AmaxX) {X = AmaxX;}
        if (Y < AminY) {Y = AminY;}
        if (Y > AmaxY) {Y = AmaxY;}
     
         map.setCenter(new google.maps.LatLng(Y,X));
      }


}

if (navigator.onLine) {
	google.maps.event.addDomListener(window, 'load', initialize);
}
else {
	alert("You must be connected to the internet for the viewer to work.")
}

// Normalizes the coords that tiles repeat across the x axis (horizontally)
// like the standard Google map tiles.
function getNormalizedCoord(coord, zoom) {
	var y = coord.y;
    var x = coord.x;

    // tile range in one direction range is dependent on zoom level
    // 0 = 1 tile, 1 = 2 tiles, 2 = 4 tiles, 3 = 8 tiles, etc
    var tileRange = 1 << zoom;

    // don't repeat across y-axis (vertically)
    if (y < 0 || y >= tileRange) {
    	return null;
	}

	// repeat across x-axis
    if (x < 0 || x >= tileRange) {
    	return null;
    }

	return {
		x: x,
        y: y
	};
}
              
function checkBounds() { 
	// Get some info about the current state of the map 
    var C = map.getCenter(); 
    var lng = C.lng(); 
    var lat = C.lat(); 
    var B = map.getBounds();
    var sw = B.getSouthWest(); 
    var ne = B.getNorthEast(); 
    // Figure out if the image is outside of the artificial boundaries 
    // created by our custom projection object. 
    var new_lat = lat; 
    var new_lng = lng; 
    
    if (sw.lat() < -50) { 
    	new_lat = lat - (sw.lat() + 50); 
    } 
    else if (ne.lat() > 50) { 
    	new_lat = lat - (ne.lat() - 50); 
    } 
    if (sw.lng() < -50) { 
		new_lng = lng - (sw.lng() + 50); 
	} 
    else if (ne.lng() > 50) {
    	new_lng = lng - (ne.lng() - 50); 
    } 
    // If necessary, move the map 
    if (new_lat != lat || new_lng != lng) { 
    	map.setCenter(new GLatLng(new_lat,new_lng)); 
    } 
}		