library(dplyr)
library(reshape2)
library(tibble)
library(MASS)
library(ggplot2)
library(caret)
library(DataExplorer)

options(max.print=999999)

# Import data from a .csv file
setwd("C:\\Users\\vchan\\Downloads\\Kompella\\6040\\Fw__Quiz_For_Data_Mining (2)")

myData <- read.csv(file="character-deaths.csv", sep=",", header=TRUE, stringsAsFactors=FALSE)

# Examine data structure
# 917 observations of 13 variables
view(myData)
glimpse(myData)

#plot character_deaths dataset
plot_intro(myData)
DataExplorer::plot_histogram(myData)

# Display data summary
summary(myData)


# Check missing value : Death.Year:612;Book.of.Death:610;Death.Chapter:618;Book.Intro.Chapter:12
sapply(myData, function(x) sum(x == '', na.rm = TRUE))
colSums(is.na(myData))

# Check duplicate rows: 0 duplicate rows
myData[duplicated(myData)]

# Convert varaibles to factor
myData$Name <- factor(myData$Name)
myData$Allegiances <- factor(myData$Allegiances)

#Summary and structure of data
#Character Myles appeared more than once; Considered that as 3 different people as they were
#introduced in different books and different chapters
summary(myData)
str(myData, list.len=ncol(myData))

view(myData)

#Filtering NA rows of dataset
#FilterData <- filter(myData, (!is.na(Death.Year) & !is.na(Book.of.Death) & is.na(Death.Chapter)) |
                  
                  #(is.na(Death.Year) & !is.na(Book.of.Death) & !is.na(Death.Chapter)) |
                  
                  #(is.na(Death.Year) & is.na(Book.of.Death) & !is.na(Death.Chapter)) |
                  
                  #(is.na(Book.Intro.Chapter)))


#NAs in Death.Year represent both characters that are not dead and missing values
#Consider only missing data to subset and remove from the dataset
CleanData<-subset(myData, (!is.na(Death.Year) & !is.na(Book.of.Death) & is.na(Death.Chapter)) |
                    
                    (is.na(Death.Year) & !is.na(Book.of.Death) & !is.na(Death.Chapter)) |
                    
                    (is.na(Death.Year) & is.na(Book.of.Death) & !is.na(Death.Chapter)) |
                    
                    (is.na(Book.Intro.Chapter)))


view(CleanData)

#checking percentage of missing values of each feature
#missing data = no.of rows of CleanData-header;(n-1) 
#missing values: 2.5% of the dataset
n = nrow(CleanData)
pMiss <- function(myData){(n-1)/length(myData)*100}
apply(myData,2,pMiss)


#Removing missing values from myData that is 2.5% of entire dataset
myData <- myData[-c(5,6,8,20,27,72,94,158,268,307,393,394,422,436,460,496,547,579,610,629,638,652,760,838),]
view(myData)

#Add new column Dead as dependent variable for predicting outcome
#If Death.Year is NA then character is considered not dead
#Dead: 1-dead 0-not dead
myData$Dead <- ifelse(is.na(myData$Death.Year), 1, 0)

#Replace NAs to 0 to add more information to dataset and results in change of variance
fun_zero <- function(myData) {
  myData[is.na(myData)] <- 0
  return(myData)
}
myData <- fun_zero(myData)

view(myData)

str(myData)


# Convert varaibles to integer 
myData$Death.Chapter <- as.integer(myData$Death.Chapter)
myData$Book.of.Death <- as.integer(myData$Book.of.Death)
myData$Death.Year <- as.integer(myData$Death.Year)
myData$Dead <- as.integer(myData$Dead)


# Convert relevant variables to numeric for correlation analysis
myData <- myData %>% mutate_if(is.factor, as.numeric)

str(myData)

# Show correlations
cor(myData)

# Create a correlation matrix
corMatrix <- round(cor(myData),2)

# Convert the correlation matrix into pairs of variables with their corresponding correlation coefficient

# Helper functions
# Get lower triangle of the correlation matrix
get_lower_tri<-function(cormat){
  cormat[upper.tri(cormat)] <- NA
  return(cormat)
}
# Get upper triangle of the correlation matrix
get_upper_tri <- function(cormat){
  cormat[lower.tri(cormat)]<- NA
  return(cormat)
}
reorder_cormat <- function(cormat){
  # Use correlation between variables as distance
  dd <- as.dist((1-cormat)/2)
  hc <- hclust(dd)
  cormat <-cormat[hc$order, hc$order]
}

# Reorder the correlation matrix
corMatrix <- reorder_cormat(corMatrix)
upper_tri <- get_upper_tri(corMatrix)

# Melt the correlation matrix
meltedCorMatrix <- melt(upper_tri, na.rm = TRUE)

# Create a ggheatmap for correlation matrix
ggheatmap <- ggplot(meltedCorMatrix, aes(Var2, Var1, fill = value))+
  geom_tile(color = "white")+
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                       midpoint = 0, limit = c(-1,1), space = "Lab", 
                       name="Correlation") +
  theme_minimal()+ # minimal theme
  theme(axis.text.x = element_text(angle = 45, vjust = 1, 
                                   size = 10, hjust = 1))+
  coord_fixed()

ggheatmap + 
  geom_text(aes(Var2, Var1, label = value), color = "black", size = 2) +
  theme(
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    panel.grid.major = element_blank(),
    panel.border = element_blank(),
    panel.background = element_blank(),
    axis.ticks = element_blank(),
    legend.justification = c(1, 0),
    legend.position = c(0.6, 0.7),
    legend.direction = "horizontal")+
  guides(fill = guide_colorbar(barwidth = 7, barheight = 1,
                               title.position = "top", title.hjust = 0.5))

# Display highly correlated variables
# Features Dead, Death.Year, Death.Chapter and Book.of.Death indicating possible multicollinearity
corX = meltedCorMatrix[abs(meltedCorMatrix$value)> 0.1,]
corX[abs(corX$value) != 1.00,]

str(myData)

#Creating newData without the variables Dead, Death.Year, Death.Chapter and Book.of.Death 
newData <- myData[,-c(1,2)]

view(newData)

# Build logistic regression model with all variables- factor variables name and Allegiances
#AIC:1786
#very high p values suggesting an inaccurate model

model1 <- glm(Dead ~ ., family=binomial(link="logit"), data=newData)
summary(model1)

# Build logistic regression model with all variables- factor variables name and Allegiances
#removing variables suggesting multicollinearity
#AIC:994.12
model2 <- glm(Dead ~ .-Book.of.Death - Death.Year -Death.Chapter, family=binomial(link="logit"), data=newData)
summary(model2)


# Build model2 with forward stepwise regression model;start with a null model
#model 3 AIC:992.13
model0 <- glm(Dead ~ 1, family=binomial(link="logit"), data=newData)
summary(model0)
model3 <- step(model0, scope=list(lower=model0, upper=model2), direction="forward")
summary(model3)

# Variable importance of model1 in order
vImp <- varImp(model2)
vImp <- data.frame(Variables = rownames(vImp), Overall = vImp$Overall)
vImp[order(vImp$Overall,decreasing = T),]

# Variable importance of model2 in order
vImp <- varImp(model3)
vImp <- data.frame(Variables = rownames(vImp), Overall = vImp$Overall)
vImp[order(vImp$Overall,decreasing = T),]

# Show variables in model1 and model2 with p-value < 0.05
summary(model2)$coef[summary(model2)$coef[,4] < 0.05, ]
summary(model3)$coef[summary(model3)$coef[,4] < 0.05, ]

# Show variables in model1 and model2 with p-value > 0.05
summary(model2)$coef[summary(model2)$coef[,4] > 0.05, ]
summary(model3)$coef[summary(model3)$coef[,4] > 0.05, ]

# Show positive and negative coefficient estimates of model2
summary(model2)$coef[summary(model2)$coef[,1] > 0, ]
length(model2$coefficients[model2$coefficients > 0])
summary(model3)$coef[summary(model3)$coef[,1] < 0, ]
length(model3$coefficients[model3$coefficients < 0])

# Show positive and negative coefficient estimates of model3
summary(model2)$coef[summary(model2)$coef[,1] > 0, ]
length(model2$coefficients[model2$coefficients > 0])
summary(model3)$coef[summary(model3)$coef[,1] < 0, ]
length(model3$coefficients[model3$coefficients < 0])

# Predict probability of Dead=1 from logistic model model2:
pred3 <- predict(model3, newdata = newData, type = "response")
pred2 <- predict(model2, newdata = newData, type = "response")

# Categorize predicted probabilities as either Dead=1 or Dead=0 based on a cutoff value of 0.5 
y_pred_num3 <- ifelse(pred3 > 0.5, 1, 0)
y_pred_num2 <- ifelse(pred2 > 0.5, 1, 0)
y_predicted3 <- factor(y_pred_num3, levels=c(0, 1))
y_predicted2 <- factor(y_pred_num2, levels=c(0, 1))

# Evaluate model3 by calculating accuracy: Misclassification Error
# model2 accuracy: 0.6987682
y_observed <- newData$Dead
accuracy3 <- mean(y_predicted3 == y_observed)
accuracy2 <- mean(y_predicted2 == y_observed)
cbind(accuracy3, accuracy2)

#Model 4 Decision Tree 

#calculating proportion of Dead vs Alive in the dataset column Dead
prop.table(table(newData$Dead))

library(rpart)
library(rpart.plot)
fit <- rpart(Dead ~ .-Book.of.Death - Death.Year -Death.Chapter, data = newData, method = 'class')
rpart.plot(fit, extra = 106)

DTree_predict <-predict(fit, newData, type = 'class')

table_mat <- table(newData$Dead, DTree_predict)
table_mat

accuracy4 <- sum(diag(table_mat)) / sum(table_mat)
print(paste('Accuracy for test', accuracy4))


stepmodel <- step(model2, scope=list(lower=model2, upper=fit), direction="forward")
summary(stepmodel)


summary(stepmodel)$coef[summary(stepmodel)$coef[,1] < 0, ]
length(stepmodel$coefficients[stepmodel$coefficients < 0])


steppred <- predict(stepmodel, newdata = newData, type = "response")
steppred



steppred <- ifelse(steppred > 0.5, 1, 0)
steppred <- factor(steppred, levels=c(0, 1))


y_observed <- newData$Dead
accuracy3 <- mean(y_predicted3 == y_observed)
accuracy2 <- mean(y_predicted2 == y_observed)
Stepaccuracy <- mean(steppred == y_observed)
cbind(accuracy3, accuracy2, Stepaccuracy)

