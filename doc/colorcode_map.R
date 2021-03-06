library(shiny)
library(leaflet)
library(data.table)
library(dplyr)
blocks = fread('../output/blocks_Manhattan.csv')
restrooms = fread('../data/restroom_coordinates.csv')
fountains = fread('../data/drink_location.csv')
source('../lib/get_points_from_segment.R')

fountains = fountains %>%
  select(lon, lat) %>%
  filter(!is.na(lon) & !is.na(lat))


ui <- bootstrapPage(
  #tags$head(includeCSS("../doc/styles.css")),
  tags$style(type = "text/css", "html, body {width:100%;height:100%}"),
  leafletOutput("map", width = "100%", height = "100%"),
  absolutePanel(class = "panel panel-default", top = 10, right = 10,
                h4("Select preferences"),
                sliderInput("tree", "   Trees:", min=1, max=100, value=50),
                sliderInput("slope", label = "   Slope:", min=1, max=100, value=50),
                checkboxInput("show_restrooms", "Show restrooms", FALSE),
                checkboxInput("show_fountains", "Show fountains", FALSE)
  )
)



server <- function(input, output, session) {
  
  # initialize map:
  map = leaflet() %>%
    addTiles() %>%
    setView(lng = -73.96, lat = 40.81, zoom = 16)
  
  
  # select subset of segments to display in the area of view:
  update_ind = reactive({
    bounds = input$map_bounds
    with(blocks, which( (start_lon<bounds$east | end_lon<bounds$east) &
                          (start_lon>bounds$west | end_lon>bounds$west) &
                          (start_lat>bounds$south | end_lat>bounds$south) &
                          (start_lat<bounds$north | end_lat<bounds$north) ) )
  })
  
  
  # create icons:
  toilet_icon <- makeIcon(
    iconUrl = "../data/Bathroom-gender-sign.png",
    iconWidth = 30, iconHeight = 30
  )
  fountain_icon <- makeIcon(
    iconUrl = "../data/aiga-drinking-fountain-bg.png",
    iconWidth = 30, iconHeight = 30
  )
  
  # draw icons if wanted:
  observe({
    leafletProxy("map") %>% clearMarkers() 
    if (input$show_restrooms)
      leafletProxy("map") %>% addMarkers(lng = restrooms$LNG, lat = restrooms$LAT, icon = toilet_icon)
    if (input$show_fountains)
      leafletProxy("map") %>% addMarkers(lng = fountains$lon, lat = fountains$lat, icon = fountain_icon)
  })
  
  
  #draw segments:
  colors = colorRamp(c("red", "black", "green"))
  
  observe({
    score = input$tree*(blocks$tree_dens)  +  input$slope*(-blocks$slope)
    score = score[update_ind()]
    score = rank(score)
    
    leafletProxy("map") %>% clearShapes()  
    k = 0
    for(i in update_ind()){
      k = k + 1
      seg_points = get_points_from_segment(blocks$the_geom[i])
      leafletProxy("map") %>% addPolylines(lng = seg_points$lon, 
                                           lat = seg_points$lat,   
                                           col = rgb(colors(score[k]/max(score))/255),
                                           weight = 7, 
                                           opacity = 1)
    }
    
  })
  
  # render map:
  output$map = renderLeaflet({
    map
  })
  
  
}

shinyApp(ui, server)


