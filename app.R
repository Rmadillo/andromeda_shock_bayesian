# ANDROMDA-SHOCK Bayesian Re-Analysis
# Adapted from code by Dan Lane

library(shiny)
library(tidyverse)

ui <- fluidPage(
  h3("ANDROMEDA-SHOCK: Bayesian Re-Analysis"),
  hr(),
  uiOutput("link_paper"),
  uiOutput("link_discourse"),
  br(),
  renderText(expr = output$paper_link),
   sidebarLayout(
      sidebarPanel(
         sliderInput("theta",
                     "Prior Mean:",
                     min = 0.5,
                     max = 1.25,
                     value = 1,
                     step = 0.01,
                     ticks = FALSE),
         hr(),
         sliderInput("hr",
                     "Cutoff for HR for computing the width of the prior distribution (e.g., MCID):",
                     min = 0.25,
                     max = 1.25,
                     value = 0.5,
                     step = 0.01,
                     ticks = FALSE),
         sliderInput("pr",
                     "Probability that the HR is less than this cutoff:",
                     min = 0,
                     max = 1,
                     value = 0.05,
                     step = 0.01,
                     ticks = FALSE),
         hr(),
         sliderInput("sd",
                     "Prior SD:",
                     min = 0.1,
                     max = 1,
                     value = 0.42,
                     step = 0.01,
                     ticks = FALSE)
      ),
      
      # Show a plot of the generated distributions
      mainPanel(
         plotOutput("distPlot")
      )
   )
)

server <- function(input, output, session) {
   
  # Calculating MCID using the estimated reductions from the power calculation 
  
  a <- 0.3 * 420 # Intervention and Outcome
  b <- 0.45 * 420 # Control and Outcome
  c <- 420 - a # Intervention No Outcome
  d <- 420 - b # Control No Outcome
  
  MCID <- ((a+0.5) * (d+0.5))/((b+0.5) * (c+0.5))
  
  # Publication Data
  HR <- 0.75
  UC <- 1.02
  
  # Calculate Priors
  theta_in <- reactive({input$theta})
  sd_in <- reactive({input$sd})
  hr_in <- reactive({input$hr})
  pr_in <- reactive({input$pr})
  
  # Update sliders based on SD and Pr and HR
  observeEvent(input$sd, {
    updateSliderInput(session,
                      inputId = "pr",
                      label = "Probability that the HR is less than this cutoff:",
                      value = round(pnorm(log(hr_in()), log(theta_in()), sd_in()), 3)
    )
  })
  
  observeEvent(input$hr, {
    updateSliderInput(session,
                      inputId = "pr",
                      label = "Probability that the HR is less than this cutoff:",
                      value = round(pnorm(log(hr_in()), log(theta_in()), sd_in()), 3),
                      min = round(pnorm(log(hr_in()), log(theta_in()), 0.1), 3),
                      max = round(pnorm(log(hr_in()), log(theta_in()), 1), 3)
                      )

  })
  
  observeEvent(input$theta, {
    updateSliderInput(session,
                      inputId = "pr",
                      label = "Probability that the HR is less than this cutoff:",
                      value = round(pnorm(log(hr_in()), log(theta_in()), sd_in()), 3),
                      min = round(pnorm(log(hr_in()), log(theta_in()), 0.1), 3),
                      max = round(pnorm(log(hr_in()), log(theta_in()), 1), 3)
                      )
  })
  
  observeEvent(input$pr, {
    updateSliderInput(session,
                      inputId = "sd",
                      label = "Prior SD:",
                      value = round((log(hr_in()) - log(theta_in()))/qnorm(pr_in()), 3)
                      
                      ## prior.sd <- (log(1.0)-log(MCID-0.05))/1.96
    )
  })
  
  prior.theta <- reactive({log(theta_in())})
  prior.sd <- reactive({sd_in()})
  
  # Calculate Likelihood
  L.theta <- log(HR)
  L.sd <- (log(UC)-log(HR))/1.96
  
  # Calculate Posterior
  post.theta <- reactive({((prior.theta()/(prior.sd())^2)+(L.theta/L.sd^2))/((1/(prior.sd())^2)+(1/L.sd^2))})
  post.sd <- reactive({sqrt(1/((1/(prior.sd())^2)+(1/L.sd^2)))})
  
  # Plot data
  x <- seq(-3, 3, by = 0.01)
  prior_plot <- reactive({dnorm(x, prior.theta(), prior.sd())})
  likelihood_plot <- dnorm(x, L.theta, L.sd)
  posterior_plot <- reactive({dnorm(x, post.theta(), post.sd())})
  
  plot_data <- reactive({
    tibble(
      x = rep(x, 3)
    ) %>%
      mutate(
        dist = rep(c("prior", "likelihood", "posterior"), each = nrow(.) / 3),
        y = c(prior_plot(), likelihood_plot, posterior_plot()),
        x = exp(x),
        y = exp(y)
      )
      
  })
  
  # Dynamic Plot
   output$distPlot <- renderPlot({
     plot_data() %>%
       ggplot(aes(x = x, y = y, group = dist)) + 
       geom_vline(xintercept = 1, linetype = "dashed",
                  color = "grey50", alpha = 0.75) + 
       geom_line(aes(color = dist),
                 size = 0.75) + 
       scale_color_brewer(name = NULL, type = "qual", palette = "Dark2",
                          breaks = c("prior", "likelihood", "posterior"),
                          labels = c("Prior", "Likelihood", "Posterior")) + 
       xlim(0, 2) + 
       labs(
         x = "Hazard Ratio",
         y = "Probability Density"
       ) + 
       annotate(geom = "text",
                label = paste("Posterior Probability HR < 1: ", 
                              round(pnorm(log(1), post.theta(), post.sd(), 
                                          lower.tail = TRUE), 3), sep = ""),
                x = 2, y = max(plot_data()$y), hjust = 1,
                fontface = "bold") + 
       theme_classic() + 
       theme(
         legend.position = "bottom",
         text = element_text(family = "Gill Sans MT"),
         axis.ticks.y = element_blank(),
         axis.text.y = element_blank(),
         axis.title = element_text(size = 15),
         axis.text = element_text(size = 12),
         legend.text = element_text(size = 12)
       )
   })
   
   # Link for paper
   url_paper <- a("Original Paper", 
                  href="https://jamanetwork.com/journals/jama/fullarticle/2724361")
   url_discourse <- a("DataMethods Discussion", 
                      href="https://discourse.datamethods.org/t/andromeda-shock-or-how-to-intepret-hr-0-76-95-ci-0-55-1-02-p-0-06/1349")
   output$link_paper <- renderUI({
     tagList(url_paper)
   })
   output$link_discourse <- renderUI({
     tagList(url_discourse)
   })
}

# Run the application 
shinyApp(ui = ui, server = server)

