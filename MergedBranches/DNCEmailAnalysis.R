library(igraph)
library(readtext)
library(tidyverse)
library(tnet)
library(cluster)    # clustering algorithms
library(readxl)
#library(mallet)
library(NLP)
library(tm)
library(SnowballC)
library(topicmodels)
library(tidyr)
library(tidytext)
library(dplyr)


setwd("C:/Users/Matthew/Desktop/Data-Mining-Project/MDupont")
emailEdges <-  read_excel("EmailDataset.xlsx", sheet = "EdgeList")
emailAttributes <- read_excel("EmailDataset.xlsx", sheet = "Attributes")

setwd("C:/Users/Matthew/Desktop/Data-Mining-Project/MDupont/Images")
set.seed(1234)

###########################################################################
#   Initial Network Construction, Analysis
###########################################################################
network.directed <- graph.data.frame(emailEdges, directed = TRUE)

#Collapse network edges into weights
E(network.directed)$weight <- 1
network.directed.weighted <- igraph::simplify(network.directed, edge.attr.comb=list(weight='sum', email= 'concat', 'ignore'))

# centrality metrics = 
V(network.directed)$degree      <- degree(network.directed)
V(network.directed)$betweenness <- betweenness(network.directed, weights = NULL)

V(network.directed.weighted)$degree      <- degree(network.directed.weighted)
V(network.directed.weighted)$betweenness <- betweenness(network.directed.weighted, weights = NULL)

##################################Visualization parameters#################
#
# edge size
#E(network.directed.weighted)$weight <- data.df$V3
E(network.directed.weighted)$width <- ifelse(E(network.directed.weighted)$weight>142, 10, 
                              ifelse(E(network.directed.weighted)$weight>99, 5, 
                                     ifelse(E(network.directed.weighted)$weight>61, 2, 1)))
E(network.directed.weighted)$color <- ifelse(E(network.directed.weighted)$weight>61, "blue", "lightgray")
E(network.directed.weighted)$arrow.size <- .3

# node color
V(network.directed.weighted)$color <- ifelse(V(network.directed.weighted)$degree>100, "red", "black")
V(network.directed.weighted)$frame.color <- ifelse(V(network.directed.weighted)$degree>100, "red", "black")
# node size
V(network.directed.weighted)$size <- ifelse(V(network.directed.weighted)$degree>100, 5, 1)
# node label
V(network.directed.weighted)$label <- ifelse(V(network.directed.weighted)$degree>100, V(network.directed.weighted)$name, "")
V(network.directed.weighted)$label <- ""
##########################################################################


network.directed.layout <- layout_with_fr(network.directed, grid='nogrid')
network.directed.weighted.layout = layout_with_fr(network.directed.weighted, grid='nogrid')

#Write to file
svg('DNCEmailNetwork.svg', width = 10, height = 10)
plot(network.directed.weighted, layout = network.directed.weighted.layout)
dev.off()

###########################################################################
#   Degree Distribution, Examination of Degree
###########################################################################
V(network.directed)$indegree <- degree(network.directed, mode = c("in"))
V(network.directed)$outdegree <- degree(network.directed, mode = c("out"))

sendersOnly = subset(V(network.directed), V(network.directed)$indegree == 0)
recipientsOnly = subset(V(network.directed), V(network.directed)$outdegree == 0)

senderDegreeHistogram = as.data.frame(table(V(network.directed)$outdegree))
senderDegreeHistogram[,1] <- as.numeric(senderDegreeHistogram[,1])

svg(filename = 'SenderOutDegreeDistribution.svg', width = 10, height = 10)
plot(
  senderDegreeHistogram,
  log = "xy",
  xlab = "SenderOutDegree",
  ylab = "Frequency")
dev.off()


recipientDegreeHistogram = as.data.frame(table(V(network.directed)$indegree))
recipientDegreeHistogram[,1] <- as.numeric(recipientDegreeHistogram[,1])

svg(filename = 'RecipientIndegreeHistogram.svg', width = 10, height = 10)
plot(
  for (i in (1: length(V(network.directed.weighted)$name)))DegreeHistogram,
  log = "xy",
  xlab = "RecipientInDegree",
  ylab = "Frequency")
dev.off()


inDegreeHistogram = as.data.frame(table(V(network.directed)$indegree))
inDegreeHistogram[,1] <- as.numeric(inDegreeHistogram[,1])

svg(filename = 'InDegreeDistribution.svg', width = 10, height = 10)
plot(
  senderDegreeHistogram,
  log = "xy",
  xlab = "InDegree",
  ylab = "Frequency")
dev.off()

outDegreeHistogram = as.data.frame(table(V(network.directed)$outdegree))
outDegreeHistogram[,1] <- as.numeric(outDegreeHistogram[,1])

svg(filename = 'OutDegreeDistribution.svg', width = 10, height = 10)
plot(
  senderDegreeHistogram,
  log = "xy",
  xlab = "OutDegree",
  ylab = "Frequency")
dev.off()

#########################################################
#                      Cluster Analysis
#########################################################

# cluster
graph.clusters <- clusters(network.directed.weighted)
cluster.vector <- graph.clusters$membership[which(graph.clusters$membership==1)]
cluster.vector <- names(cluster.vector)
graph.sub <- subgraph(network.directed.weighted, cluster.vector)
com <- cluster_spinglass(graph.sub, spins=12)

# set cluster color
for (i in 1:length(V(network.directed.weighted)$name))
{
  idx <- which(com$name==V(network.directed.weighted)$name[i])
  if (length(idx) == 0) {
    V(network.directed.weighted)$color[i] = 1
  }
  else {
    V(network.directed.weighted)$color[i] = com$membership[idx] + 1
  }
}
V(network.directed.weighted)$frame.color <- V(network.directed.weighted)$color

minC <- rep(-Inf, vcount(network.directed.weighted))
maxC <- rep(Inf, vcount(network.directed.weighted))
minC[1] <- maxC[1] <- 0
co <- layout_with_fr(network.directed.weighted, minx=minC, maxx=maxC,
                     miny=minC, maxy=maxC, grid='nogrid')


svg(filename = "plot-force-directed.svg", width = 10, height = 10)
plot(network.directed.weighted, layout=layout_with_fr, edge.arrow.size=0,
     rescale=FALSE, 
     xlim=range(co[,1]), ylim=range(co[,2]), 
     vertex.label.dist=0, vertex.label.color="green", vertext.label.cex=50000)
dev.off()

svg(filename = "plot-with-clusters.svg")
plot(network.directed.weighted, layout=layout_with_fr, edge.arrow.size=0,
     rescale=FALSE, 
     xlim=range(co[,1]), ylim=range(co[,2]))
dev.off()


#########################################################
#                     Start LDA
#########################################################

emails <- emailAttributes
halfEmails <- emails[sample(1:nrow(emails), 11228, replace=FALSE),]  # get a random sample of half of the normal data
emailbodies <- halfEmails$body
docs <- Corpus(VectorSource(emailbodies)) # create corpus from vector of email bodies
writeLines(as.character(docs[[2]]))       # inspect particular document in corpus

# removing potentially problematic symbols
toSpace <- content_transformer(function(x, pattern) { return (gsub(pattern, ' ', x))})
docs <- tm_map(docs, toSpace, '-')
docs <- tm_map(docs, toSpace, '\'')
docs <- tm_map(docs, toSpace, "\"")

# remove punctuation
docs <- tm_map(docs, removePunctuation)
#Strip digits
docs <- tm_map(docs, removeNumbers)
#remove stopwords
docs <- tm_map(docs, removeWords, stopwords('english'))
#remove whitespace
docs <- tm_map(docs, stripWhitespace)
#Good practice to check every now and then
writeLines(as.character(docs[[30]]))
#Stem document
docs <- tm_map(docs,stemDocument)


#Create document-term matrix
dtm <- DocumentTermMatrix(docs)
#collapse matrix by summing over columns
freq <- colSums(as.matrix(dtm))
#length should be total number of terms
length(freq)
#create sort order (descending)
ord <- order(freq,decreasing=TRUE)
#List all terms in decreasing order of freq and write to disk
freq[ord]
#write.csv(freq[ord],'/Users/Joey/Desktop/word_freq.csv')


# R threw some hiccups. fixing error from above. (dont know how to explain it but error is reproducable without running next 2 lines)
raw.sum <- apply(dtm, 1, FUN=sum) # sum each row of the table
dtm <- dtm[raw.sum!=0,] # delete all raws with 0

#Run LDA using Gibbs sampling
ldaOut <-LDA(dtm, k=4, control = list(seed=1234))
emails_lda <- ldaOut

emails_topics <- tidy(emails_lda, matrix = "beta")
emails_topics

# gives us the top n words for each topic
#   normally show 20 words per topic; change to ... top_n(20, beta) ...
# 
emails_top_terms <- emails_topics %>%
  group_by(topic) %>%
  top_n(20, beta) %>%
  ungroup() %>%
  arrange(topic, -beta)

# take the top terms and make a pretty visualization of the distribution above
#   he wants to see visualizations like this in the project
#   normally show 20 words per topic; gives a better qual observation of whats happening
emails_top_terms %>%
  mutate(term = reorder_within(term, beta, topic)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip() +
  scale_x_reordered()

# side-by-side comparison of the probability of each word in a topic
# 
beta_spread <- emails_topics %>%
  mutate(topic = paste0("topic", topic)) %>%
  spread(topic, beta) %>%
  filter(topic1 > .001 | topic2 > .001) %>%
  mutate(log_ratio = log2(topic2 / topic1))

beta_spread

# gives the probability of a topic within a document
#
emails_documents <- tidy(emails_lda, matrix = "gamma")
emails_documents

# the specific words and their frequencies within a document
#
tidy(halfEmails) %>%
  filter(document == 6) %>%
  arrange(desc(count))

######################################################################
#                   Attempt to graph topics in clusters
######################################################################