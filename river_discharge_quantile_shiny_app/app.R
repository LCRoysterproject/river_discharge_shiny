library("tidyverse")
library("lubridate")
library("waterData")
library("shiny")
library("shinythemes")
library("scales")

# station and site
station = '02323500'   
stinfo  = siteInfo(station)


# Load data and dynamically check if data needs to be updated
dis <- read_rds("data/dis1.rds")
if (max(dis$dates) < (Sys.Date() - 5)) {
  sdate <- max(dis$dates) + 1
  newdis <- importDVs(staid = station, code = '00060', stat = '00003', sdate= as.character(sdate))
  dis <- bind_rows(dis, newdis) %>%
    distinct() # In case there's repeated rows due to code failure
  write_rds(dis, "data/dis1.rds")
}

# Data carpentries and create quantile data table
dis_noleap <- dis %>%
  filter(!(month(dates) == 2 & day(dates) == 29))
#na.omit()#<- removing the leap day year for all years that have it

dis_quant <- dis_noleap %>%
  mutate(md = strftime(dates, format = "%m-%d")) %>%
  group_by(md) %>%
  summarise(quan10 = quantile(val, 0.10, na.rm=TRUE),
            quan25 = quantile(val, 0.25, na.rm=TRUE),
            quan75 = quantile(val, 0.75, na.rm=TRUE),
            quan90 = quantile(val, 0.90, na.rm=TRUE),
            quan100 = quantile(val, 1, na.rm=TRUE)) %>%
  gather("quantile", "val", -md)

dis_quant$quantile <- str_remove(dis_quant$quantile, "quan") %>%
  factor(levels = c("100", "90", "75", "25", "10"))

#### UI ####
ui <- fluidPage(theme = shinytheme("united"), 
  
  titlePanel("Suwannee River Discharge Quantiles"),
  
  sidebarLayout(
    sidebarPanel(
      
      h4("Percentile Description"),
      helpText("A percentile is a value on a scale of one hundred that indicates the percent of a distribution that is equal to or below it. For example, on the map of daily streamflow conditions a river discharge at the 90th percentile is equal to or greater than 90 percent of the discharge values recorded on this day of the year during all years that measurements have been made.  In general,a percentile greater than 75 is considered above normal, a percentile between 25 and 75 is considered normal, and a percentile less than 25 is considered below normal"),
      
      h4("Data"),
      helpText("These data are retrieved via the `waterData` package in R made available by U.S. Geological Survey (USGS). These data are collected at the USGS 02323500 Suwannee River station near Wilcox, Florida. This site is located in Levy County, Florida (latitude 29.58968 and longitude -82.93651 in degrees)."),
      
      sliderInput("yoi",
                  "Year:",
                  min = 1950, sep = "",
                  max = year(Sys.Date()),
                  value = year(Sys.Date()),
                  step = 1)
    ),

    
    mainPanel(
      width = 7,
      plotOutput("quant_plot", height = "600px"),
      downloadButton(outputId = "download_quant", label = "Download this figure")
    )
  )
)

#### SERVER ####
server <- function(input, output) {
  
  quant_plot<- reactive({
    
    dis_quant1 <- dis_quant %>%
      mutate(dates = paste(input$yoi, md, sep="-") %>% as.Date)
    
    dis_yoi <- dis_noleap %>%
      filter(year(dates) == input$yoi)
    
    cbPalette <- c("mediumpurple3", "darkslategray2", "palegreen2", "sandybrown", "indianred4")
    
  
    quant_plot<- ggplot(dis_yoi, aes(x=dates, y=val)) +
      ggtitle(paste("Suwannee River Discharge Quantiles for",input$yoi)) +
      xlab("Month")+
      ylab("River Discharge (ft^3)") +
      labs(fill= "Quantile") +
      geom_ribbon(data = dis_quant1, aes(x=dates, ymax=val, ymin=min(val), fill=quantile)) +
      geom_line(size=1.2) +
      scale_fill_manual(values=cbPalette, labels = c("90-100", "75-90", "25-75", "10-25", "0-10")) +
      scale_x_date(labels = date_format("%B")) +
      theme_minimal() +
      theme(panel.border = element_rect(colour = "black", fill=NA, size=1),
            axis.text=element_text(size=14),
            axis.title=element_text(size=14,face="bold")) +
      scale_y_continuous(limits=c(0, 60000))
    
    quant_plot
  })
 
   
  output$quant_plot <-renderPlot({
    quant_plot()
    
  })
  
  output$download_quant<- downloadHandler(
    filename = function() {
      "plot.jpeg"
    },
    content = function(file) {
      ggsave(file,  quant_plot(), width = 10, height = 10)
    }
  )
  
}

# Run the application 
shinyApp(ui = ui, server = server)