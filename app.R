library(shiny)
library(DBI)
library(shinyjs)

# Define a list of words for the game
words <- c("hangman", "programming", "shiny", "authentication", "azure", "container")

# This function creates a connection engine using sys env creds -----------
conn <- function(.driver = driver,
                 .server = server,
                 .database = database,
                 .uid = uid,
                 .pwd = pwd ,
                 .port = port,
                 .trusted_connection = trusted_connection){
  DBI::dbConnect(odbc::odbc(),
                 driver = .driver,
                 server = .server,
                 database = .database,
                 uid = .uid,
                 pwd = .pwd,
                 port = .port,
                 trusted_connection = .trusted_connection)
}

# This function test manual connection to server ---------------------------------
test_conn <- function(driver,
                      server,
                      database,
                      port,
                      trusted_connection,
                      uid,
                      pwd) {
  .GlobalEnv$`admin_conn` <-
    conn(
      .driver = driver,
      .server = server,
      .database = database,
      .port = port,
      .trusted_connection = trusted_connection,
      .uid = uid,
      .pwd = pwd
    )
  
  # result <-
  #   dbIsValid(.GlobalEnv$`admin_conn`)
  
  # return(result)
}
# This function creates a form for server specs -------------
server_conn_form <- function(.driver = driver,
                             .server = server,
                             .database = database,
                             .port = port,
                             .trusted_connection = trusted_connection,
                             .uid = uid,
                             .pwd = pwd)
{
  shiny::tagList(
    shiny::tags$h3("Server Specs"),
    textInput(
      inputId = "driver",
      label = "Driver",
      value = .driver,
      placeholder = "Enter conn driver name"
    ),
    textInput(
      inputId = "server",
      label = "Server",
      value = .server,
      placeholder = "Enter conn server name"
    ),
    textInput(
      inputId = "database",
      label = "Database",
      value = .database,
      placeholder = "Enter conn database name"
    ),
    textInput(
      inputId = "port",
      label = "Port",
      value = .port,
      placeholder = "Enter conn port name"
    ),
    selectInput(
      inputId = "trusted_connection",
      label = "Trusted Connection",
      choices = c("", "true", "false"),
      selected = .trusted_connection 
    ),
    textInput(
      inputId = "uid",
      label = "UID",
      value = NULL,
      placeholder = "Enter conn UID"
    ),
    passwordInput(
      inputId = "pwd",
      label = "PWD",
      value = NULL,
      placeholder = "Enter conn PWD"
    ),
    selectInput(
      inputId = "connection_timeout",
      label = "Connection Timeout", 
      choices = list("1 Minute" = 60000, "5 Minutes" = 300000, "10 Minutes" = 600000),
      selected = list("10 Minutes" = 600000)
    )
  )
}

# UI ------------
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$script(src = "auth.js")
  ),
  tags$header(
    style = "background-color: #f2f2f2;
             padding: 10px;
             display: flex;
             justify-content: space-between;
             height: 50px;
             align-items: center;
             position: fixed;
             top: 0;
             width: 100%;
             margin-left: -15px;",
    titlePanel("Hangman Game"),
    # logout button
    tags$a(
      href = "/.auth/logout?post_logout_redirect_uri=/",
      tags$i(class = "fa fa-sign-out", style = "font-size: 20px; color: #000000; margin-right: 10px;"),
    )
  ),
  
  mainPanel(
    style = "margin-top: 50px;",
    h3("Guess the word!"),
    textOutput("word_display"),
    br(),
    textInput("guess_input", "Enter a letter:"),
    tagAppendAttributes(style = "background-color:steelblue;color:white;",
                        actionButton("guess_button", icon = icon("lightbulb"), "Guess")),
    br(),
    br(),
    h4("Incorrect Guesses:"),
    textOutput("incorrect_guesses"),
    br(),
    h4("Remaining Chances:"),
    textOutput("remaining_chances"),
    br(),
    tagAppendAttributes(style = "background-color:orange;color:white;",
                        actionButton("reset_button", icon = icon("redo"), "Reset")),
    hr(),
    actionButton("db_conn", icon = icon("database"), "Connect")
  )
)

# Server -------------
server <- function(input, output, session) {
  
  observe({
    
    req(input$AzureAuth)
    
    if (input$AzureAuth$name == "unknown") {
      showNotification("Hey there 👋", duration = 5, type = "message")
    } else {
      showNotification(paste0("Hey ", input$AzureAuth$name, " 👋"), duration = 5, type = "message")
    }
    
  })
  
  observeEvent(input$db_conn, {
    showModal(
      modalDialog(
        title = "Connect to a db",
        server_conn_form(
          .driver = NULL,
          .server = NULL,
          .database = NULL,
          .port = NULL,
          .trusted_connection = NULL,
          .uid = NULL,
          .pwd = NULL
        ),
        uiOutput("qry_text"),
        verbatimTextOutput("qry_result_table"),
        footer = tagList(
          actionButton("testAdminConn", paste("Test Connection"), class = "btn-success"),
          modalButton('Close')
        )
      )
    )
  })
  
  # observeEvent - input$testAdminConn --------------------------------------
  observeEvent(input$testAdminConn, {
    print("Testing connection", col = 31)
    print(input$connection_timeout)
    tryCatch(
      expr = 
        {
          test <- test_conn(
            driver = input$driver,
            server = input$server,
            database = input$database,
            port = input$port,
            trusted_connection = input$trusted_connection,
            uid = input$uid,
            pwd = input$pwd
          )
          print(paste0("Connected to ",input$server,".[", input$database, "]"))
          showNotification(paste0("Connected to ",input$server,".[", input$database, "]"), duration = 5, type = "message")
          
        },
      error = function(e) {
        warning(e$message)
        showNotification(e$message, duration = 5, type = "error")
      })
    
    # Render UIInputs Table ---------------------------------------------------
    if (exists("admin_conn")) {
      # req(dbIsValid(admin_conn))
      # reactive_data$UIInputs_data <- get_data("UIInputs", where = " 1=1 ORDER BY Id DESC", mydb = admin_conn, disconnect = FALSE)
      
      # Render UIInputs_data
      output$qry_text <-
        renderUI(
          tagList(
            textAreaInput(
              inputId = "qry",
              label = "Query"
            ),
            actionButton(
              inputId = "run_qry",
              label = NULL,
              icon = icon("play")
            )
          )
        )
      
      observeEvent(input$run_qry,{
        print(input$qry)
        qry_result <- DBI::dbGetQuery(admin_conn, input$qry)
        print(qry_result)
        
        output$qry_result_table <-
          renderPrint(qry_result)
      })
      
    } else {
      expr = 
        showNotification("No valid connection exisits to the database.", duration = 5, type = "error")
    }
    
    print(paste("Checking if `admin_conn` is valid and disconnecting in", as.numeric(input$connection_timeout)/1000/60 ,"minutes if it does"))
    shinyjs::delay(
      as.numeric(input$connection_timeout),
      if (dbIsValid(admin_conn)) {
        dbDisconnect(admin_conn)
        print("Auto Timeout..Disconnected from database")
        expr = 
          showNotification("Disconnected from databse.", duration = 5, type = "message")
      }
    )
  })
  
  # Initialize game state
  game_state <- reactiveValues(
    word = sample(words, 1),  # Randomly select a word from the list
    guessed_letters = character(0),  # Store guessed letters
    incorrect_guesses = 0,  # Count of incorrect guesses
    remaining_chances = 7  # Total chances before game over
  )
  
  # Function to update game state based on user guess
  update_game_state <- function() {
    
    guess <- tolower(substr(input$guess_input, 1, 1))  # Extract first character of user's guess
    
    if (guess %in% game_state$guessed_letters) {
      # Letter has already been guessed, do nothing
      return()
    }
    
    game_state$guessed_letters <- c(game_state$guessed_letters, guess)
    
    if (!(guess %in% strsplit(game_state$word, "")[[1]])) {
      # Incorrect guess
      game_state$incorrect_guesses <- game_state$incorrect_guesses + 1
      print(game_state$word)
    }
    
    if (game_state$incorrect_guesses >= game_state$remaining_chances) {
      # Game over
      showGameOverMessage()
    }
  }
  
  # Action when the guess button is clicked
  observeEvent(input$guess_button, {
    update_game_state()
  })
  
  # Function to display the word with guessed letters filled in
  output$word_display <- renderText({
    word <- game_state$word
    guessed_letters <- game_state$guessed_letters
    
    displayed_word <- sapply(strsplit(word, "")[[1]], function(x) {
      if (x %in% guessed_letters) {
        x
      } else {
        "_"
      }
    })
    
    paste(displayed_word, collapse = " ")
  })
  
  # Display incorrect guesses
  output$incorrect_guesses <- renderText({
    if(length(game_state$guessed_letters) == 0){
      "No incorrect guesses yet 👀 "
    } else {
      paste(game_state$guessed_letters[!(game_state$guessed_letters %in% strsplit(game_state$word, "")[[1]])], collapse = ", ")
    }
  })
  
  # Display remaining chances
  output$remaining_chances <- renderText({
    game_state$remaining_chances - game_state$incorrect_guesses
  })
  
  # Function to display game over message
  showGameOverMessage <- function() {
    showModal(modalDialog(
      title = "Game Over",
      paste("You ran out of chances! The word was", game_state$word),
      easyClose = TRUE
    ))
    
    # Reset game state
    game_state$word <- sample(words, 1)
    game_state$guessed_letters <- character(0)
    game_state$incorrect_guesses <- 0
  }
  
  observeEvent(input$reset_button, {
    
    game_state$word <- sample(words, 1)
    game_state$guessed_letters <- character(0)
    game_state$incorrect_guesses <- 0
    game_state$remaining_chances <- 7
    
    updateTextInput(session = session,
                    inputId = "guess_input",
                    value = "")
    
  })
}

shinyApp(ui, server)
