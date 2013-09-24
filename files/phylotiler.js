// Initialize function
function initialize() {
    // Create an array to hold all the markers
	// This is needed when removing them during zoom level changes
	var allMarkers = [];
	
	// Set the options for the image tiles
	var imageTypeOptions = {
		// Gets the path where the tiles are stored
		getTileUrl: function(coord, zoom) {
				var normalizedCoord = getNormalizedCoord(coord, zoom);
				if (!normalizedCoord) {
					return null;
				}
				var bound = Math.pow(2, zoom);
				return  "tiles/" + zoom + "/" + normalizedCoord.x + "-" + (normalizedCoord.y) + ".jpg";

		},
		// Sets the default Google Maps tile size
		tileSize: new google.maps.Size(256, 256),
			maxZoom: maxzoom,
			minZoom: minzoom,
			radius: 1738000,
			name: "Tree"
	};
	
	// This creates the image map type for using your own tiles
	var imageMapType = new google.maps.ImageMapType(imageTypeOptions);			
	
	// Center the map
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
				
	// Create the map
	var map = new google.maps.Map(document.getElementById("map_canvas"), myOptions);
	map.mapTypes.set('tree', imageMapType);
	map.setMapTypeId('tree');
    
	/***** The followin section deals with conversion of the pin points (where 0,0 is the left corner) to a Latitude and Longitude plane *****/
	
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
					
	/*********************************************************************************************************************************/
	
	// Sets the allowed size that the map can move in
	var allowedBounds = new google.maps.LatLngBounds(
		projection.fromPointToLatLng(new google.maps.Point(0, treesize)),
		projection.fromPointToLatLng(new google.maps.Point(treesize, 0))        
	);
	
	// Checks when the zoom changes. This clears all the pins and readds them while checking their zoom JSON value
	google.maps.event.addListener(map, 'zoom_changed', function () {
		map.clearOverlays();
		addMarkers();
	});
	
	// Clear all the markers.  Uses the allMarkers variable which all the pins have
	google.maps.Map.prototype.clearOverlays = function() {
		  for (var i = 0; i < allMarkers.length; i++ ) {
			allMarkers[i].setMap(null);
		  }
		}

		  
	// Used to check whether the zoom JSON field has any values
	function isEmpty(obj) {
	    return Object.keys(obj).length === 0;
	}
	
	
	// Add all the markers in the JSON data
	function addMarkers() {
		
		// Loop through all of the markers
		for (var i = 0; i < nodedata.markers.length; i++) {
			
			var currentZoom = map.getZoom();
			var matchZoom = false;
			// Loop through all of the zoom values (if they exist)
			for(var j=0;j< nodedata.markers[i].zoom.length;j++){
			     if (nodedata.markers[i].zoom[j] == currentZoom) {
			    	 matchZoom = true;
			     }
		    }
			
			// If no zoom values are set or the zoom value is matched
			if (isEmpty(nodedata.markers[i].zoom) || matchZoom == true) {
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
				var marker = new MarkerWithLabel({
					position: projection.fromPointToLatLng(
					   new google.maps.Point(nodedata.markers[i].x, nodedata.markers[i].y)
					),
					map: map,
					title:"Marker",
					content: bubblecontent,
					icon: "https://maps.gstatic.com/intl/en_ALL/mapfiles/markers2/measle.png",
					labelContent: nodedata.markers[i].hovertext
				});
				
				allMarkers.push(marker);
						
				var infoWindow = new google.maps.InfoWindow();
								            
				google.maps.event.addListener(marker, 'click', function () {
					infoWindow.setContent(this.content);
					infoWindow.open(map, this);
			    });
			}
		}
		
		// Check the bounds when the center changes
	    google.maps.event.addListener(map, 'center_changed', function() {
			checkBounds();
		});
	}
	
	
	// Checks the bounds of the map
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

// This is used to make sure the user is connected to the Internet.  If not, Google Maps will not work.
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