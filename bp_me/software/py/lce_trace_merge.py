import os
import sys
import argparse

def readLines(f):
  return [l for l in f.readlines() if 'ReqLat' not in l]

def getLineSets(lines):
  lineSets = {}
  for l in lines:
    lineSet = []
    i = l.find('|')
    tLine = int(l[0:i].strip())
    if tLine in lineSets:
      lineSets[tLine].append(l)
    else:
      lineSets[tLine] = [l]
  return lineSets

def combineTraces(inDir, outFile):
  # find all the trace files in inDir
  traceFilePaths = sorted([os.path.abspath(inDir+'/'+f) for f in os.listdir(inDir) if os.path.isfile(inDir+'/'+f)])
  traceFiles = {}
  for p in traceFilePaths:
    traceFiles[traceFilePaths.index(p)] = open(p, 'r')
    print(p)

  lineSets = {}
  for i,f in traceFiles.items():
    lineSets[i] = getLineSets(readLines(f))
    f.close()

  # combine line sets
  with open(outFile, 'w') as of:
    done = False
    while not done:
      # pick lineSet with smallest time across all lineSets
      minTime = 2**64
      mintSet = 0
      for i,s in lineSets.items():
        t = min(s.keys())
        if t < minTime:
          minTime = t
          minSet = i

      # write lines to output file
      of.writelines(lineSets[minSet][minTime])
      lineSets[minSet].pop(minTime)

      # check for empty lineSets and remove
      deletes = []
      for i,s in lineSets.items():
        if not s:
          deletes.append(i)
      for i in deletes:
        lineSets.pop(i)

      done = not lineSets

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--path', dest='path', metavar='./', help='path to directory with lce_.trace files', required=True)
  parser.add_argument('--out', dest='out', metavar='out.trace', help='output file', required=True)

  args = parser.parse_args()

  inDir = os.path.abspath(args.path)
  outFile = os.path.abspath(args.out)

  combineTraces(inDir, outFile)

