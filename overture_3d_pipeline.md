# Overture 3D Pipeline (Philippines)

This script uses DuckDB to extract Overture Maps themes and Python to normalize elevations.

## 1. Extraction (DuckDB SQL)
Run this inside a SQL environment with the `spatial` and `httpfs` extensions.

```sql
-- INSTALL spatial, httpfs;
-- LOAD spatial, httpfs;

-- Set up Philippines Bounding Box (approx)
SET variable bbox_min_lon = 116.0;
SET variable bbox_min_lat = 4.0;
SET variable bbox_max_lon = 127.0;
SET variable bbox_max_lat = 21.0;

-- 1. Extract Buildings
COPY (
    SELECT 
        id,
        geometry,
        names.primary AS name,
        height,
        num_floors,
        ground_elev,
        roof_shape
    FROM read_parquet('s3://overturemaps-us-west-2/release/2024-02-15-alpha.0/theme=buildings/type=building/*', hive_partitioning=1)
    WHERE bbox.minX > get_variable('bbox_min_lon') 
      AND bbox.maxX < get_variable('bbox_max_lon')
      AND bbox.minY > get_variable('bbox_min_lat')
      AND bbox.maxY < get_variable('bbox_max_lat')
) TO 'ph_buildings.geojson' WITH (FORMAT GDAL, DRIVER 'GeoJSON');

-- 2. Extract Transportation (Roads)
COPY (
    SELECT 
        id,
        geometry,
        class,
        surface
    FROM read_parquet('s3://overturemaps-us-west-2/release/2024-02-15-alpha.0/theme=transportation/type=segment/*', hive_partitioning=1)
    WHERE bbox.minX > get_variable('bbox_min_lon') 
      AND bbox.maxX < get_variable('bbox_max_lon')
      AND bbox.minY > get_variable('bbox_min_lat')
      AND bbox.maxY < get_variable('bbox_max_lat')
) TO 'ph_roads.geojson' WITH (FORMAT GDAL, DRIVER 'GeoJSON');
```

## 2. Elevation Normalization (Python)
Ensure `rasterio` and `geopandas` are installed.

```python
import geopandas as gpd
import rasterio
from shapely.geometry import Point

def normalize_elevations(geojson_path, dem_path, output_path):
    # Load buildings and DEM
    gdf = gpd.read_file(geojson_path)
    dem = rasterio.open(dem_path)
    
    def get_elev(geom):
        # Sample elevation at centroid
        coords = geom.centroid.coords[0]
        for val in dem.sample([coords]):
            return float(val[0])
            
    # Normalize ground elevation to terrain surface
    gdf['base_elev'] = gdf.geometry.apply(get_elev)
    
    # Calculate absolute roof elevation
    # Overture height is fallback if ground_elev is null
    gdf['roof_elev'] = gdf['base_elev'] + gdf['height'].fillna(gdf['num_floors'] * 3.5).fillna(10)
    
    # Save processed data
    gdf.to_file(output_path, driver='GeoJSON')
    print(f"Processed 3D buildings saved to {output_path}")

# normalize_elevations('ph_buildings.geojson', 'ph_terrain_srtm.tif', 'ph_buildings_3d.geojson')
```

## 3. Stylistic & Integration
### MapLibre / Vector Tile Styles (Dark Mode)
Apply these JSON properties to your layer styles for a high-contrast dark look:

```json
{
  "id": "buildings-3d",
  "type": "fill-extrusion",
  "source": "overture-buildings",
  "paint": {
    "fill-extrusion-color": "#2a2a2a",
    "fill-extrusion-height": ["get", "roof_elev"],
    "fill-extrusion-base": ["get", "base_elev"],
    "fill-extrusion-opacity": 0.8,
    "fill-extrusion-vertical-gradient": true
  }
}
```

### QGIS Integration
1. **Add Terrain**: Drag your `ph_terrain_srtm.tif` into QGIS.
2. **Add Buildings**: Drag `ph_buildings_3d.geojson`.
3. **Set 3D Renderer**: 
   - Right-click Layer -> Properties -> 3D View.
   - Set "Extrusion" to `roof_elev - base_elev`.
   - Set "Altitude Clamping" to `Absolute`.
   - Set "Altitude Binding" to `Centroid`.

## 4. Normalization Verification
- **Sinking Check**: The `base_elev` attribute reflects the ground surface at the building centroid. By using "Absolute" clamping in QGIS or MapLibre, buildings will follow the terrain curves perfectly.
- **Draping Roads**: In QGIS, set the road layer to "Drape" over the elevation surface in the 3D view settings.
