setClass(Class = "TFsEnrichInRegions",
         contains = "EnrichStep"
)

setMethod(
    f = "init",
    signature = "TFsEnrichInRegions",
    definition = function(.Object,prevSteps = list(),...){
        allparam <- list(...)
        inputRegionBed <- allparam[["inputRegionBed"]]
        inputForegroundGeneBed <- allparam[["inputForegroundGeneBed"]]
        inputBackgroundGeneBed <- allparam[["inputBackgroundGeneBed"]]
        inputRegionMotifBed <- allparam[["inputRegionMotifBed"]]
        outputTFsEnrichTxt <- allparam[["outputTFsEnrichTxt"]]
        inputMotifWeights <- allparam[["inputMotifWeights"]]
        inputTFgeneRelMtx <- allparam[["inputTFgeneRelMtx"]]
        inputMotifTFTable <- allparam[["inputMotifTFTable"]]
        if(length(prevSteps)>0){
            GenBackgroundStep <- prevSteps[[1]]
            FindMotifsInRegionsStep  <- prevSteps[[2]]
            RegionConnectTargetGeneStep  <- prevSteps[[3]]
            input(.Object)$inputRegionBed <-
                getParam(GenBackgroundStep,"outputRegionBed")
            input(.Object)$inputRegionMotifBed <-
                getParam(FindMotifsInRegionsStep,"outputRegionMotifBed")
            input(.Object)$inputForegroundGeneBed <-
                getParam(RegionConnectTargetGeneStep,"outputForegroundBed")
            input(.Object)$inputBackgroundGeneBed <-
                getParam(RegionConnectTargetGeneStep,"outputBackgroundBed")
        }

        if(!is.null(inputRegionBed)){
            input(.Object)$inputRegionBed <- inputRegionBed
        }
        if(!is.null(inputRegionMotifBed)){
            input(.Object)$inputRegionMotifBed <- inputRegionMotifBed
        }
        if(!is.null(inputForegroundGeneBed)){
            input(.Object)$inputForegroundGeneBed <- inputForegroundGeneBed
        }
        if(!is.null(inputBackgroundGeneBed)){
            input(.Object)$inputBackgroundGeneBed <- inputBackgroundGeneBed
        }




        if(is.null(outputTFsEnrichTxt)){
            output(.Object)$outputTFsEnrichTxt <-
                getAutoPath(.Object,originPath =
                                .Object$inputList[["inputRegionBed"]],
                            regexSuffixName = "allregion.bed",
                            suffix = "PECA_TF_enrich.txt")
        }else{
            output(.Object)$outputTFsEnrichTxt <- outputTFsEnrichTxt
        }

        if(!is.null(inputRegionBed)){
            input(.Object)$inputRegionBed <- inputRegionBed
        }
        if(!is.null(inputRegionMotifBed)){
            input(.Object)$inputRegionMotifBed <- inputRegionMotifBed
        }
        if(!is.null(inputForegroundGeneBed)){
            input(.Object)$inputForegroundGeneBed <- inputForegroundGeneBed
        }
        if(!is.null(inputBackgroundGeneBed)){
            input(.Object)$inputBackgroundGeneBed <- inputBackgroundGeneBed
        }

        if(is.null(inputMotifWeights)){
            input(.Object)$inputMotifWeights <- getRefFiles("MotifWeights")
        }else{
            input(.Object)$inputMotifWeights <- inputMotifWeights
        }
        if(is.null(inputTFgeneRelMtx)){
            input(.Object)$inputTFgeneRelMtx <- getRefFiles("TFgeneRelMtx")
        }else{
            input(.Object)$inputTFgeneRelMtx <- inputTFgeneRelMtx
        }
        if(is.null(inputMotifTFTable)){
            input(.Object)$inputMotifTFTable <- getRefFiles("MotifTFTable")
        }else{
            input(.Object)$inputMotifTFTable <- inputMotifTFTable
        }
        .Object
    }
)


setMethod(
    f = "processing",
    signature = "TFsEnrichInRegions",
    definition = function(.Object,...){


        inputRegionBed <- getParam(.Object,"inputRegionBed")
        inputForegroundGeneBed <- getParam(.Object,"inputForegroundGeneBed")
        inputBackgroundGeneBed <- getParam(.Object,"inputBackgroundGeneBed")
        inputRegionMotifBed <- getParam(.Object,"inputRegionMotifBed")
        outputTFsEnrichTxt <- getParam(.Object,"outputTFsEnrichTxt")
        inputMotifWeights <- getParam(.Object,"inputMotifWeights")
        inputTFgeneRelMtx <- getParam(.Object,"inputTFgeneRelMtx")
        inputMotifTFTable <- getParam(.Object,"inputMotifTFTable")
        #return(.Object)


        if(endsWith(inputMotifWeights,".RData")){

            inputMotifWeights <- get(load(inputMotifWeights))
        }else{
            inputMotifWeights<- read.table(inputMotifWeights,sep = '\t',
                                           header = FALSE)
            colnames(inputMotifWeights) <- c("motifName","motifWeight")
        }

        if(endsWith(inputTFgeneRelMtx,".RData")){

            inputTFgeneRelMtx <- get(load(inputTFgeneRelMtx))
        }else{
            inputTFgeneRelMtx<- read.table(inputTFgeneRelMtx,sep = '\t',
                                           header = TRUE)
        }

        if(endsWith(inputMotifTFTable,".RData")){
            inputMotifTFTable <- get(load(inputMotifTFTable))
        }else{
            inputMotifTFTable<- read.table(inputMotifTFTable,sep = '\t',
                                           header = FALSE)
            colnames(inputMotifTFTable) <- c("motifName", "tfName")
        }



        geneName <- colnames(inputTFgeneRelMtx)
        genes <- data.frame(geneName = geneName, name =
                                seq_len(length(geneName)))
        tfName <- rownames(inputTFgeneRelMtx)
        tfs <- data.frame(tfName = tfName, name = seq_len(length(tfName)))
        inputMotifWeights <- cbind(inputMotifWeights,
                                   seq_len(nrow(inputMotifWeights)))
        motifName <- as.character(inputMotifWeights[,1])
        motifWeight <- as.numeric(inputMotifWeights[,2])

        regionBed <- import.bed(con = inputRegionBed)
        foregroundGeneBed  <- read.table(inputForegroundGeneBed,sep = "\t")
        colnames(foregroundGeneBed) <- c("seqnames","start","end",
                                         "name","score",
                                         "geneName","blockCount")
        foregroundGeneBed <- foregroundGeneBed[
            !duplicated(foregroundGeneBed[,c("name","geneName")]),]
        backgroundGeneBed<-
            tryCatch({read.table(inputBackgroundGeneBed,sep = "\t")},
                     error = function(e){
#            writeLog(.Object,as.character(e))
            pValue <- matrix(1,nrow = length(tfName),ncol = 4)

            pValue<-data.frame(TF = tfName, Motif_enrichment = pValue[,1],
                               Targt_gene_enrichment = pValue[,2],
                               P_value = pValue[,3], FDR = pValue[,4])

            write.table(pValue,file = outputTFsEnrichTxt,quote = FALSE,
                        row.names = FALSE,sep = "\t")
            return(.Object)

        })
        if(inherits(backgroundGeneBed,"Step")){
            return(backgroundGeneBed)
        }

        colnames(backgroundGeneBed)  <- c("seqnames","start","end",
                                          "name","score",
                                          "geneName","blockCount")
        backgroundGeneBed <-
            backgroundGeneBed[!duplicated(backgroundGeneBed[
                ,c("name","geneName")]),]
        regionMotifBed <- read.table(inputRegionMotifBed,sep = "\t")
        colnames(regionMotifBed) <- c("seqnames","start","end",
                                      "name","score","strand","motifName")

        motifWeight1 <- log(1/(motifWeight + 0.1) + 1)
        motifidx <- match(regionMotifBed$motifName,motifName)
        inputMotifWeights <- cbind(inputMotifWeights,motifWeight1)
        regionMotifWeight <- inputMotifWeights[motifidx[!is.na(motifidx)],]

        #        foregroundRegionGene <- merge(x=foregroundGeneBed,y=genes, by.x = "geneName" ,  by.y = "genName")
        #        backgroundRegionGene <- merge(x=backgroundGeneBed,y=genes, by.x = "geneName" ,  by.y = "genName")

        #        rbind(foregroundRegionGene,backgroundRegionGene)

        pValue <- matrix(1,nrow = length(tfName),ncol = 4)


        cl <- makeCluster(getThreads())

        tfsseq = seq_len(length(tfName))
        # if(getGenome() =="testgenome"){
        #     tfsseq= tfsseq[tfsseq%%10==0]
        # }

        #for(i in 1:length(tfName)){
        allpValue<-parLapply(X = tfsseq, fun = function(i, geneName,
                                                        tfName,
                                                        pValue,
                                                        inputTFgeneRelMtx,
                                                        foregroundGeneBed,
                                                        backgroundGeneBed,
                                                        inputMotifTFTable,
                                                        regionMotifBed){

            tryCatch({
            pValue[i,2] <- t.test(x = inputTFgeneRelMtx[i,match(
                backgroundGeneBed$geneName,geneName)],
                                  y = inputTFgeneRelMtx[i,match(
                                      foregroundGeneBed$geneName,geneName)],
                                  alternative = "greater")$p.value

            motifsOfTF <- inputMotifTFTable[
                inputMotifTFTable$tfName == tfName[i],1]

            if(length(motifsOfTF)==0){
                return(pValue[i,]) #next
            }
            print(Sys.time())
            pvalueOfFisher<- lapply(seq_len(length(motifsOfTF)),
                                    function(motifsOfTFi) {
                motif <- as.character(motifsOfTF[motifsOfTFi])

                regionsName <- regionMotifBed[
                    regionMotifBed$motifName == motif, c("name")]
                foregroundGeneFalledInMotifReiong<-
                    match(foregroundGeneBed$name, regionsName)
                backgroundGeneFalledInMotifReiong<-
                    match(backgroundGeneBed$name, regionsName)


                fisherMtx <- matrix(0,nrow = 2,ncol = 2)
                fisherMtx[1,1] <- sum(!is.na(foregroundGeneFalledInMotifReiong))
                fisherMtx[1,2] <- sum(is.na(foregroundGeneFalledInMotifReiong))
                fisherMtx[2,1] <- sum(!is.na(backgroundGeneFalledInMotifReiong))
                fisherMtx[2,2] <- sum(is.na(backgroundGeneFalledInMotifReiong))

                fisher.test(fisherMtx)$p.value
            })
            pvalueOfFisher <- do.call("c",pvalueOfFisher)
            pValue[i,1] <- min(pvalueOfFisher)
            motif <- as.character(motifsOfTF[which.min(pvalueOfFisher)])
            regionsName <- regionMotifBed[
                regionMotifBed$motifName == motif, c("name")]
            foregroundGeneFalledInMotifReiong<-
                match(foregroundGeneBed$name , regionsName)
            backgroundGeneFalledInMotifReiong<-
                match(backgroundGeneBed$name , regionsName)
            pvalueOfFisher1 <- lapply(-9:9, function(cut_off){
                cut_off <- cut_off /10
                genesName <- geneName[inputTFgeneRelMtx[i,] > cut_off]
                foregroundGeneAboveCutOff<-
                    match(foregroundGeneBed$geneName , genesName)
                backgroundGeneAboveCutOff<-
                    match(backgroundGeneBed$geneName , genesName)

                forePos <- is.na(foregroundGeneFalledInMotifReiong) &
                    is.na(foregroundGeneAboveCutOff)
                backPos <- is.na(backgroundGeneFalledInMotifReiong) &
                    is.na(backgroundGeneAboveCutOff)

                fisherMtx <- matrix(0,nrow = 2,ncol = 2)
                fisherMtx[1,1] <- sum(!forePos)
                fisherMtx[1,2] <- sum(forePos)
                fisherMtx[2,1] <- sum(!backPos)
                fisherMtx[2,2] <- sum(backPos)

                fisher.test(fisherMtx)$p.value
            })

            pvalueOfFisher1 <- do.call("c", pvalueOfFisher1)

            pValue[i,3] <- min(pvalueOfFisher1)
            },error = function(e){
                writeLog(.Object,as.character(e))
            })
            writeLog(.Object,as.character(i))
            return(pValue[i,])

        }
        ,geneName
        ,tfName
        ,pValue
        ,inputTFgeneRelMtx =inputTFgeneRelMtx,
        foregroundGeneBed = foregroundGeneBed,
        backgroundGeneBed =backgroundGeneBed,
        inputMotifTFTable =inputMotifTFTable,
        regionMotifBed = regionMotifBed,
        cl = cl)
        pValue <- matrix(unlist(allpValue),nrow = length(tfName),
                         ncol = 4,byrow = TRUE)

        stopCluster(cl)

        pValue[is.na(pValue)] <- 1
        pValue[pValue>1] <- 1

        pValue[,4] <- p.adjust(pValue[,3],method = "fdr")

        score=-log10(pValue[,3])
        pValue<-data.frame(TF = tfName, Motif_enrichment = pValue[,1],
                           Targt_gene_enrichment = pValue[,2],
                           P_value = pValue[,3], FDR = pValue[,4])

        pValue <- pValue[order(score,decreasing = TRUE),]

        write.table(pValue,file = outputTFsEnrichTxt,quote = FALSE,
                    row.names = FALSE,sep = "\t")

        .Object
    }
)


setMethod(
    f = "genReport",
    signature = "TFsEnrichInRegions",
    definition = function(.Object, ...){
        .Object
    }
)




#' @name TFsEnrichInRegions
#' @title Test each TF is enriched in regions or not
#' @description
#' Test each TF is enriched in regions or not
#' @param prevStep \code{\link{Step-class}} object scalar.
#' This parameter is available when the upstream step function
#' (printMap() to see the previous functions)
#' have been sucessfully called.
#' Accepted value can be the object return by any step function or be feed by
#' \code{\%>\%} from last step function.
#' @param inputRegionBed \code{Character} scalar.
#' Directory of Regions BED file  including foreground and background
#' @param inputForegroundGeneBed \code{Character} scalar.
#' Directory of BED file  including foreground regions connected
#' to related genes. The forth column is region ID
#' @param inputBackgroundGeneBed \code{Character} scalar.
#' Directory BED file including foreground regions connected
#' to related genes. The forth column is region ID
#' @param inputRegionMotifBed \code{Character} scalar.
#' Directory BED file  including foreground regions matched motifs.
#' The forth column is region ID.
#' The fifth column is motif calling score. The sixth column is motif name.
#' @param outputTFsEnrichTxt \code{Character} scalar.
#' Directory of Text result file  with five columns.
#' The first columns is transcription factor ,The second column is xxxx
#' @param inputMotifWeights \code{Character} scalar.
#' Directory of Text file contain motif weight. The first column is motif name.
#' The second column is the weight.
#' Default: NULL (if \code{setGenome} is called.)
#' @param inputTFgeneRelMtx \code{Character} scalar.
#' Directory of Text file contain a Transcription Factior(TF) and
#' Gene relation weight matrix.
#' Default: NULL (if \code{setGenome} is called.)
#' @param inputMotifTFTable \code{Character} scalar.
#' Directory of Text file contain  Transcription Factior(TF)
#' (the first column) and motif name(the second column).
#' Default: NULL (if \code{setGenome} is called.)
#' @param ... Additional arguments, currently unused.
#' @details
#' Connect foreground and background regions to targetGene.
#' If you only use this function without previous steps and
#' you do not familiar with the data format of the input,
#' you can run the example to see the example input from previous steps.
#' @return An invisible \code{\link{EnrichStep-class}} object
#' (\code{\link{Step-class}} based) scalar for downstream analysis.
#' @author Zheng Wei
#' @seealso
#' \code{\link{genBackground}}
#' \code{\link{findMotifsInRegions}}
#' \code{\link{tfsEnrichInRegions}}
#' @examples
#'
#' library(magrittr)
#' setGenome("testgenome") #Use "hg19","hg38",etc. for your application
#' foregroundBedPath <- system.file(package = "enrichTF", "extdata","testregion.bed")
#' gen <- genBackground(inputForegroundBed = foregroundBedPath)
#' conTG <- enrichRegionConnectTargetGene(gen)
#' findMotif <- enrichFindMotifsInRegions(gen,motifRc="integrate")
#' result <- enrichTFsEnrichInRegions(gen)
#'
#' genBackground(inputForegroundBed = foregroundBedPath) %>%
#'     enrichRegionConnectTargetGene %>%
#'     enrichFindMotifsInRegions(motifRc="integrate") %>%
#'     enrichTFsEnrichInRegions
#'




setGeneric("enrichTFsEnrichInRegions",
           function(prevStep,
                    inputRegionBed = NULL,
                    inputForegroundGeneBed = NULL,
                    inputBackgroundGeneBed = NULL,
                    inputRegionMotifBed = NULL,
                    outputTFsEnrichTxt = NULL,
                    inputMotifWeights = NULL,
                    inputTFgeneRelMtx = NULL,
                    inputMotifTFTable = NULL,
                    ...) standardGeneric("enrichTFsEnrichInRegions"))


#' @rdname TFsEnrichInRegions
#' @aliases enrichTFsEnrichInRegions
#' @export
setMethod(
    f = "enrichTFsEnrichInRegions",
    signature = "Step",
    definition = function(prevStep,
                          inputRegionBed = NULL,
                          inputForegroundGeneBed = NULL,
                          inputBackgroundGeneBed = NULL,
                          inputRegionMotifBed = NULL,
                          outputTFsEnrichTxt = NULL,
                          inputMotifWeights = NULL,
                          inputTFgeneRelMtx = NULL,
                          inputMotifTFTable = NULL,
                          ...){
        allpara <- c(list(Class = "TFsEnrichInRegions",
                          prevSteps = list(prevStep)),
                     as.list(environment()),list(...))
        step <- do.call(new,allpara)
        invisible(step)
    }
)
#' @rdname TFsEnrichInRegions
#' @aliases tfsEnrichInRegions
#' @export
tfsEnrichInRegions <- function(inputRegionBed,
                               inputForegroundGeneBed,
                               inputBackgroundGeneBed,
                               inputRegionMotifBed,
                               outputTFsEnrichTxt = NULL,
                               inputMotifWeights = NULL,
                               inputTFgeneRelMtx = NULL,
                               inputMotifTFTable = NULL,
                               ...){
    allpara <- c(list(Class = "TFsEnrichInRegions", prevSteps = list()),
                 as.list(environment()),list(...))
    step <- do.call(new,allpara)
    invisible(step)
}
