## This awk script was written by Findlay Copley to combine the second column of numerous files together
## First line will be file names
## the rownames of the first column will be retained.
## This is good for combining HTSEQ counts. 

## FNR - per file line count, 1 is the first line of the file.
## L is an array 1D array which will contain my lines
## Here I add the filename of the file being looped to the first index. 
FNR==1 {L[0]=L[0] "\t" FILENAME }
## NR is a running total of the number of lines gone through
## So NR only == FNR when you are on the first file.
## So only on the first file take the first column and add to the array.
NR==FNR { L[FNR]=L[FNR] $1}
## add a tab and the contents of column 2 to the array.
{L[FNR]=L[FNR]  "\t" $2}
## at the end loop through the array starting at index 0 (the file names)
END { for ( i=0; i<=length(L)-1;i++) print L[i]}

