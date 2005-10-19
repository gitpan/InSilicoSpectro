ionDensityHist<-function(d, xlab, col=rainbow(dim(d)[2]), lty=1, lwd=2, br=30)
{
  n<-dim(d)[2]
  m<-0
  for (i in 1:n){
    h<-hist(d[[i]], breaks=br, plot=FALSE)
    s<-max(h$density)
    if (s > m) m<-s
  }
  h<-hist(d[[1]], breaks=br, plot=FALSE)
  plot(h$density, x=h$mids, type="l", ylim=c(0,m), main="ion probability densities", ylab="density", xlab=xlab, col=col[1], lwd=lwd, lty=lty)
  for (i in 2:n){
    h<-hist(d[[i]], breaks=br, plot=FALSE)
    lines(h$density, x=h$mids, type="l", col=col[i], lwd=lwd, lty=lty)
  }
  legend(0, m, legend=names(d), lwd=lwd, lty=lty, col=col)
}

ionFreqHist<-function(d, xlab, col=rainbow(dim(d)[2]), relative=FALSE, lty=1, lwd=2, br=30)
{
  n<-dim(d)[2]
  m<-0
  for (i in 1:n){
    h<-hist(d[[i]], breaks=br, plot=FALSE)
    s<-ifelse(relative, max(h$counts/sum(h$counts)), max(h$counts))
    if (s > m) m<-s
  }
  h<-hist(d[[1]], breaks=br, plot=FALSE)
  plot(ifelse(rep(relative, length(h$counts)), h$counts/sum(h$counts), h$counts), x=h$mids, type="l", ylim=c(0,m), main="ion relative frequencies", ylab="relative frequency", xlab=xlab, col=col[1], lwd=lwd, lty=lty)
  for (i in 2:n){
    h<-hist(d[[i]], breaks=br, plot=FALSE)
    lines(ifelse(rep(relative, length(h$counts)), h$counts/sum(h$counts), h$counts), x=h$mids, type="l", col=col[i], lwd=lwd, lty=lty)
  }
  legend(0, m, legend=names(d), lwd=lwd, lty=lty, col=col)
}

