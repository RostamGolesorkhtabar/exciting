#! /bin/sh
#
# takes a fortran module file and prints all variable
# symbols (without brackets for arrays).
#
# LIMITATIONS: 
# - works if not more than ONE variable per line is
# declared - no line continuation with the "&" character!!!
# The case 
#
#   integer, dimension(3,3) :: m
#
# is not possible!
#
# - Arrays always have to be declared like
#
#   integer :: m(3,3)
#
# with the dimension attached to the symbol name.
#
# - works only for one module per file.
#
# Author: S. Sagmeister, 16/06/2006
#

# check if all parameters are present
if [ $# -ne 3 ]; then
    echo "Wrong number of arguments"
    echo "Syntax: `basename $0`: file_name module_name routine_name"
    exit
fi

# check for module file
inpfile=$1
if [ ! -f $inpfile ]; then
	echo "No file $file present"
	exit
fi

# variables
modnam=$2
file1=.tmp1.$inpfile
file2=.tmp2.$inpfile
file3=.tmp3.$inpfile
file4=.tmp4.$inpfile
file_decol=.tmp.$inpfile.decol
file_nodecol=.tmp.$inpfile.nodecol

# remove comments and blank lines
cat $inpfile | awk -F'!' '{print $1}' | awk 'NF>0' > $file1

# begin and end of module "modnam" in "inpfile"
ismodnam=`grep -c "^ *module *$modnam" $file1`
if [ $ismodnam -ne 1 ]; then
    echo "Module name $modnam does not exist or occurs more than once"
    exit
fi
lin_endend=`cat $file1 | wc -l`
lin_begin=`grep -n "^ *module *$modnam" $file1 | head -1 | awk -F':' '{print $1}'`
lin_begin=`expr $lin_begin + 1`
cat $file1 | tail +$lin_begin > $file2
rm -f $file1
# line numbers of first "contains" and "end"
iscontains=`grep -c "^ *contains" $file2`
if [ $iscontains -gt 0 ]; then
    lin_contains=`grep -n "^ *contains" $file2 | head -1 | awk -F':' '{print $1}'`
else
    lin_contains=-1
fi
lin_end=`grep -n "^ *end" $file2 | head -1 | awk -F':' '{print $1}'`
if [ $lin_contains -gt 0 -a $lin_contains -lt $lin_end ]; then
    lin_end=$lin_contains
fi
lin_end=`expr $lin_end - 1`
cat $file2 | head -$lin_end > $file3
rm -f $file2

# match for [logical|integer|character|real|complex]
cat $file3 | egrep '^ *logical *|^ *integer *|^ *character *|^ *real *|^ *complex *'  > $file4
rm -f $file3


### OK #######

# lines without the "::" operator
cat $file4 | awk -F'::' '{print $2}' | awk 'NF>0' > $file_decol
# lines without the "::" operator
cat $file4 | grep -v '::' | awk -F'^ *logical *' '{print $2}' > $file_nodecol


exit





# set name of routine to write the fortran source code to
routine_nam=$3
routine_symb=`basename $routine_nam .f90`

cat <<EOF

Generating subroutine "$routine_nam" to dump variables from
module "$file"...
EOF






# all variables and parameters
#allvarspars=`cat $file | awk -F'!' '{print $1}' | awk 'NF>0' | awk '/logical|character|integer|real|complex/' | awk '{print $NF}' | awk -F'(' '{print $1}' | awk -F'=' '{print $1}' | sort`

# all variables and NO parameters
#allvars=`cat $file | awk -F'!' '{print $1}' | awk 'NF>0' | grep -v ', *parameter' | awk '/logical|character|integer|real|complex/' | awk '{print $NF}' | awk -F'(' '{print $1}' | awk -F'=' '{print $1}' | sort`

# scalars
#allvarspars_scalars=`cat $file | awk -F'!' '{print $1}' | awk 'NF>0' | awk '/logical|character|integer|real|complex/' | awk '{print $NF}' | awk -F'=' '{print $1}'| grep -v '(' | sort`

# arrays
#allvarspars_arrays=`cat $file | awk -F'!' '{print $1}' | awk 'NF>0' | awk '/logical|character|integer|real|complex/' | awk '{print $NF}' | awk -F'=' '{print $1}' |grep '(' | awk -F'(' '{print $1}' | sort`



echo allvarspars_scalars 
echo $allvarspars_scalars
echo 
echo allvarspars_arrays
echo $allvarspars_arrays
echo

exit


# get module name
modnam=`grep ' *module' $file | grep -v 'end *module' | awk '{print $2}'`

#
# generate fortran source code to dump variables
#

# prolog
cat <<EOF > $routine_nam

!
! Automatically generated by "`basename $0`" - script
! Date: `date`
!

subroutine $routine_symb(fnam,fu_in)
use $modnam
implicit none
! file name to dump into
character(*), intent(in) :: fnam
! file unit
integer, intent(in) :: fu_in

! local variables
integer :: fu
character(256) :: fnam_scalars, fnam_arrays

! set file unit
fu = fu_in

! set file names
fnam_scalars = fnam // '.scalars'
fnam_arrays = fnam // '.arrays'

! open file for scalars
open(fu,file=trim(fnam_scalars), action='write', status='replace')

! all scalar variables
EOF

# loop over scalars
for scalar in $allvarspars_scalars; do

cat <<EOF >> $routine_nam
write(fu,*) '$scalar:', $scalar
EOF

done

# intermezzo

cat <<EOF >> $routine_nam

! close file for scalars
close(fu)

! open file for arrays
open(fu,file=trim(fnam_arrays), action='write', status='replace')

! all array variables
EOF

# loop over arrays
for array in $allvarspars_arrays; do

cat <<EOF >> $routine_nam
!write(fu,*) '$array: shape', shape($array), ':', $array
write(fu,*) '$array: shape', shape($array)
write(fu,*) $array
EOF

done

# epilog
cat <<EOF >> $routine_nam

! close file for arrays
close(fu)

end subroutine $routine_symb

EOF

cat <<EOF
done.

EOF

#
